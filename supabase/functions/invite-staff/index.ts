// Supabase Edge Function: invite-staff
//
// Called by the Afraz Flow Flutter client:
//   client.functions.invoke('invite-staff', body: {
//     tenant_id, email, full_name, role
//   })
//
// The caller must be an active admin of the target tenant. The function uses
// the service-role key only on the server, never in the Flutter app.
//
// Deploy:
//   supabase functions deploy invite-staff
// Required secrets (set automatically by Supabase in hosted projects):
//   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
// Optional:
//   APP_URL — where invite links return after the user sets a password.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type InvitePayload = {
  tenant_id?: string;
  email?: string;
  full_name?: string;
  role?: string;
  password?: string;
};

const ALLOWED_ROLES = new Set(["admin", "manager", "cashier"]);

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: "Function is not configured" }, 500);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ error: "Missing authorization header" }, 401);
    }
    const accessToken = authHeader.slice("Bearer ".length).trim();
    if (!accessToken) {
      return json({ error: "Missing authorization token" }, 401);
    }

    // Identify the caller using their own JWT (never the service role).
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: callerData, error: callerError } =
      await callerClient.auth.getUser(accessToken);
    const caller = callerData?.user;
    if (callerError || !caller) {
      return json({ error: "Invalid or expired session" }, 401);
    }

    const payload = (await req.json().catch(() => ({}))) as InvitePayload;
    const tenantId = payload.tenant_id?.trim();
    const email = payload.email?.trim().toLowerCase();
    const fullName = payload.full_name?.trim() ?? "";
    const role = payload.role?.trim().toLowerCase() ?? "cashier";
    const providedPassword =
      typeof payload.password === "string" ? payload.password.trim() : "";
    if (providedPassword && providedPassword.length < 8) {
      return json({ error: "Temporary password must be at least 8 characters" }, 400);
    }

    if (!tenantId) return json({ error: "tenant_id is required" }, 400);
    if (!email || !email.includes("@")) {
      return json({ error: "A valid email is required" }, 400);
    }
    if (fullName.length < 2) {
      return json({ error: "The staff member's full name is required" }, 400);
    }
    if (!ALLOWED_ROLES.has(role)) {
      return json({ error: "Unsupported role" }, 400);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: membership, error: membershipError } = await admin
      .from("tenant_members")
      .select("id, role, is_active")
      .eq("tenant_id", tenantId)
      .eq("user_id", caller.id)
      .maybeSingle();

    if (membershipError) {
      return json({ error: membershipError.message }, 500);
    }
    if (!membership || !membership.is_active || membership.role !== "admin") {
      return json(
        { error: "Only an active admin can invite staff" },
        403,
      );
    }

    // Look for an existing auth user so repeat invites are idempotent.
    let userId: string | null = null;
    for (let page = 1; page <= 20 && !userId; page++) {
      const { data: listed, error: listError } = await admin.auth.admin
        .listUsers({ page, perPage: 200 });
      if (listError) {
        return json({ error: listError.message }, 500);
      }
      const users = listed?.users ?? [];
      const match = users.find(
        (user) => (user.email ?? "").toLowerCase() === email,
      );
      if (match) userId = match.id;
      if (users.length < 200) break;
    }

    let invited = false;
    // Password used for brand-new accounts. Existing accounts keep their own
    // password unless the admin explicitly supplies a new one below.
    const defaultPassword = "Welcome123";
    const passwordToUse = providedPassword || defaultPassword;

    if (!userId) {
      // Invite by email always sends an email. We then attach a concrete
      // temporary password so the cashier can sign in after confirming,
      // instead of relying on a link that only creates a session.
      const redirectTo = Deno.env.get("APP_URL")?.trim() || undefined;
      const { data: invite, error: inviteError } = await admin.auth.admin
        .inviteUserByEmail(email, {
          data: { full_name: fullName, invited_tenant_id: tenantId, role },
          redirectTo,
        });
      if (inviteError) {
        return json({ error: inviteError.message }, 400);
      }
      userId = invite?.user?.id ?? null;
      invited = true;
      if (!userId) {
        return json({ error: "The invitation could not be created" }, 500);
      }
      const { error: passwordError } = await admin.auth.admin.updateUserById(
        userId,
        { password: passwordToUse },
      );
      if (passwordError) {
        return json({ error: passwordError.message }, 400);
      }
    } else if (providedPassword) {
      // Admin explicitly re-set a password for an existing account.
      const { error: updateError } = await admin.auth.admin.updateUserById(
        userId,
        { password: providedPassword },
      );
      if (updateError) {
        return json({ error: updateError.message }, 400);
      }
    }

    // Keep public.profiles in sync even if the auth trigger is missing.
    const { error: profileError } = await admin.from("profiles").upsert(
      {
        id: userId,
        email,
        full_name: fullName,
      },
      { onConflict: "id" },
    );
    if (profileError) {
      return json({ error: profileError.message }, 500);
    }

    const { data: existing, error: existingError } = await admin
      .from("tenant_members")
      .select("id, role, is_active")
      .eq("tenant_id", tenantId)
      .eq("user_id", userId)
      .maybeSingle();
    if (existingError) {
      return json({ error: existingError.message }, 500);
    }

    if (existing) {
      if (!existing.is_active || existing.role !== role) {
        const { error: updateError } = await admin
          .from("tenant_members")
          .update({ role, is_active: true })
          .eq("id", existing.id);
        if (updateError) {
          return json({ error: updateError.message }, 500);
        }
      }
    } else {
      const { error: insertError } = await admin.from("tenant_members").insert({
        tenant_id: tenantId,
        user_id: userId,
        role,
        is_active: true,
      });
      if (insertError) {
        return json({ error: insertError.message }, 500);
      }
    }

    return json({
      ok: true,
      user_id: userId,
      email,
      role,
      invited,
      message: invited
        ? "Invitation sent"
        : "Existing account added to the team",
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message }, 500);
  }
});
