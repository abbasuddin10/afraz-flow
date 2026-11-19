// Supabase Edge Function: notify-push
//
// Sends real-time mobile push notifications for Afraz Flow over Firebase
// Cloud Messaging (FCM). It is the bridge between the Supabase database and
// FCM: whenever a row is inserted into `app_notifications` (a Daily AI
// Briefing or a dedicated Low Stock alert), a Postgres trigger posts the row
// here over pg_net, and this function looks up the recipient's device tokens
// in `fcm_tokens` and delivers the message so it arrives even when the app is
// minimised or completely closed.
//
// Expected body (from the app_notifications trigger webhook):
//   { "type": "INSERT", "record": { "user_id": "...", "title": "...",
//     "body": "...", "kind": "daily_briefing" | "low_stock", ... } }
// A direct call with `{ "notification": { ... } }` also works for testing.
//
// Authentication
// --------------
// If the PUSH_WEBHOOK_SECRET secret is set, the caller must send
// `Authorization: Bearer <PUSH_WEBHOOK_SECRET>` (the database trigger reads
// the same value from the private `app_private.push_config.webhook_secret`
// column). Unset = no check.
//
// FCM credentials (set via `supabase secrets set`):
//   FCM_SERVICE_ACCOUNT_JSON  full Firebase service-account JSON, or
//   FCM_PROJECT_ID + FCM_CLIENT_EMAIL + FCM_PRIVATE_KEY separately.
// Legacy fallback: FCM_SERVER_KEY (old server key) when no service account
// is configured.
//
// Deploy:
//   supabase functions deploy notify-push
//   supabase secrets set FCM_SERVICE_ACCOUNT_JSON='...'
//
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const ANDROID_CHANNEL_ID = "afraz_flow_alerts";
const CLICK_ACTION = "FLUTTER_NOTIFICATION_CLICK";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function asString(value: unknown, fallback = ""): string {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

function env(name: string): string {
  return Deno.env.get(name)?.trim() ?? "";
}

function base64UrlEncodeBytes(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64ToBytes(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const binary = atob(normalized);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

// ---------------------------------------------------------------------------
// FCM HTTP v1 (service account -> OAuth2 -> messages:send)
// ---------------------------------------------------------------------------

type ServiceAccount = {
  projectId: string;
  clientEmail: string;
  privateKey: string;
};

function loadServiceAccount(): ServiceAccount | null {
  const raw = env("FCM_SERVICE_ACCOUNT_JSON");
  if (raw) {
    try {
      const parsed = JSON.parse(raw);
      if (isRecord(parsed)) {
        return serviceAccountFrom(
          asString(parsed.project_id),
          asString(parsed.client_email),
          asString(parsed.private_key),
        );
      }
    } catch (error) {
      console.error("FCM_SERVICE_ACCOUNT_JSON is not valid JSON:", error);
    }
  }
  return serviceAccountFrom(
    env("FCM_PROJECT_ID"),
    env("FCM_CLIENT_EMAIL"),
    env("FCM_PRIVATE_KEY"),
  );
}

function serviceAccountFrom(
  projectId: string,
  clientEmail: string,
  privateKey: string,
): ServiceAccount | null {
  if (!projectId || !clientEmail || !privateKey) return null;
  return { projectId, clientEmail, privateKey };
}

async function getAccessToken(
  account: ServiceAccount,
): Promise<string | null> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncodeBytes(
    new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" })),
  );
  const claims = base64UrlEncodeBytes(
    new TextEncoder().encode(
      JSON.stringify({
        iss: account.clientEmail,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
      }),
    ),
  );
  const unsigned = `${header}.${claims}`;

  const pem = account.privateKey
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    base64ToBytes(pem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64UrlEncodeBytes(new Uint8Array(signature))}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const data = await response.json();
  if (!response.ok || !data?.access_token) {
    console.error("Google OAuth2 token exchange failed:", data);
    return null;
  }
  return data.access_token as string;
}

function messageData(record: Record<string, unknown>): Record<string, string> {
  return {
    kind: asString(record.kind, "general"),
    reference_id: asString(record.reference_id),
    notification_id: asString(record.id),
    dedupe_key: asString(record.dedupe_key),
    title: asString(record.title, "Afraz Flow"),
    body: asString(record.body),
  };
}

// Returns null when the token is no longer registered (should be removed).
async function sendFcm(
  token: string,
  record: Record<string, unknown>,
): Promise<"sent" | "stale" | "failed"> {
  const title = asString(record.title, "Afraz Flow");
  const body = asString(record.body);
  const data = messageData(record);

  const account = loadServiceAccount();
  if (account) {
    const accessToken = await getAccessToken(account);
    if (accessToken) {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${account.projectId}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token,
              notification: { title, body },
              android: {
                priority: "high",
                notification: {
                  channel_id: ANDROID_CHANNEL_ID,
                  click_action: CLICK_ACTION,
                },
              },
              data,
            },
          }),
        },
      );
      if (response.ok) return "sent";
      const errorBody = await response.json().catch(() => null);
      console.error("FCM v1 send failed:", response.status, errorBody);
      if (response.status === 404 || response.status === 410) return "stale";
      return "failed";
    }
  }

  // Legacy fallback (FCM server key).
  const serverKey = env("FCM_SERVER_KEY");
  if (!serverKey) {
    console.error(
      "No FCM credentials configured: set FCM_SERVICE_ACCOUNT_JSON " +
        "(or FCM_PROJECT_ID/FCM_CLIENT_EMAIL/FCM_PRIVATE_KEY, or FCM_SERVER_KEY).",
    );
    return "failed";
  }
  const response = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      Authorization: `key=${serverKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      to: token,
      priority: "high",
      notification: {
        title,
        body,
        android_channel_id: ANDROID_CHANNEL_ID,
        click_action: CLICK_ACTION,
      },
      data,
    }),
  });
  if (response.ok) {
    const result = await response.json().catch(() => null);
    if (result?.results?.[0]?.error === "NotRegistered") return "stale";
    return "sent";
  }
  const errorBody = await response.json().catch(() => null);
  console.error("Legacy FCM send failed:", response.status, errorBody);
  if (response.status === 404 || response.status === 410) return "stale";
  return "failed";
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed. Use POST." }, 405);
  }

  const secret = env("PUSH_WEBHOOK_SECRET");
  if (secret) {
    const authorization = req.headers.get("authorization") ?? "";
    if (authorization !== `Bearer ${secret}`) {
      return json({ error: "Unauthorized." }, 401);
    }
  }

  let payload: unknown;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Body must be valid JSON." }, 400);
  }
  if (!isRecord(payload)) return json({ error: "Invalid body." }, 400);

  const record = isRecord(payload.record)
    ? payload.record
    : isRecord(payload.notification)
      ? payload.notification
      : null;
  if (!record) {
    return json({ error: "Missing notification record." }, 400);
  }

  const userId = asString(record.user_id);
  if (!UUID_PATTERN.test(userId)) {
    return json({ error: "Invalid user_id." }, 400);
  }

  const supabase = createClient(
    env("SUPABASE_URL"),
    env("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { persistSession: false } },
  );

  const { data: tokenRows, error } = await supabase
    .from("fcm_tokens")
    .select("token")
    .eq("user_id", userId);

  if (error) {
    console.error("Token lookup failed:", error.message);
    return json({ error: `Token lookup failed: ${error.message}` }, 500);
  }

  const tokens = (Array.isArray(tokenRows) ? tokenRows : [])
    .map((row) => (isRecord(row) ? asString(row.token) : ""))
    .filter((token) => token.length > 0);

  if (tokens.length === 0) {
    return json({ sent: 0, stale: 0, failed: 0, detail: "No registered devices." });
  }

  let sent = 0;
  let failed = 0;
  const stale: string[] = [];
  for (const token of tokens) {
    try {
      const result = await sendFcm(token, record);
      if (result === "sent") sent += 1;
      else if (result === "stale") stale.push(token);
      else failed += 1;
    } catch (error) {
      console.error("Push delivery error:", error);
      failed += 1;
    }
  }

  if (stale.length > 0) {
    // Uninstalled app / rotated token: drop the dead rows.
    const { error: deleteError } = await supabase
      .from("fcm_tokens")
      .delete()
      .in("token", stale);
    if (deleteError) {
      console.error("Stale token cleanup failed:", deleteError.message);
    }
  }

  return json({ sent, stale: stale.length, failed });
});
