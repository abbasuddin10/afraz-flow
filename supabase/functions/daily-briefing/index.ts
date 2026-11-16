// Supabase Edge Function: daily-briefing
//
// Builds the Daily Executive Summary for Afraz Flow businesses.
//
// Two modes
// --------
// 1. Manual (admin JWT in the Authorization header)
//    An active admin taps "Generate briefing" in the app. The caller's
//    membership is verified before the service-role client is used, so a user
//    can only generate a briefing for a business they administer.
//
// 2. Scheduled (service-role key in the Authorization header)
//    A cron job invokes the function once an hour. It asks
//    `list_due_daily_summaries()` for every business whose local briefing time
//    has passed and which does not yet have a scheduled summary for today.
//
// For each business the flow is:
//   trigger_daily_reorders -> build_daily_business_snapshot -> Gemini narrative
//   -> upsert daily_summaries -> insert app_notifications for every active admin
//
// The snapshot comes from security-definer RPCs, never from model-generated SQL.
//
// Deploy:
//   supabase db push
//   supabase functions deploy daily-briefing --no-verify-jwt
//   supabase secrets set GEMINI_API_KEY=...
// Optional:
//   supabase secrets set GEMINI_MODEL=gemini-3.6-flash
//
// Schedule (in the dashboard, or via pg_cron + pg_net):
//   select cron.schedule(
//     'daily-briefing',
//     '5 * * * *',
//     $$
//     select net.http_post(
//       url := 'https://<project-ref>.supabase.co/functions/v1/daily-briefing',
//       headers := jsonb_build_object(
//         'Content-Type', 'application/json',
//         'Authorization', 'Bearer <service-role-key>'
//       ),
//       body := '{"mode":"batch"}'::jsonb
//     );
//     $$
//   );

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type BriefingPayload = {
  mode?: string;
  tenant_id?: string;
  summary_date?: string;
  timezone?: string;
  locale?: string;
};

type DueBriefing = {
  tenant_id: string;
  tenant_name: string | null;
  summary_date: string;
  briefing_timezone: string | null;
  scheduled_time: string | null;
};

type Metrics = Record<string, unknown>;

type Narrative = {
  headline: string;
  summary: string;
  highlights: string[];
  recommendations: string[];
};

type GeneratedBriefing = {
  summary: Record<string, unknown>;
  notifications: number;
  mode: "manual" | "scheduled";
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

const MAX_BATCH = 50;

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

function asNumber(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return 0;
}

function asString(value: unknown, fallback = ""): string {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

function asArray(value: unknown): Record<string, unknown>[] {
  return Array.isArray(value) ? value.filter(isRecord) : [];
}

function validTimezone(value: unknown): string | null {
  if (typeof value !== "string" || !value.trim()) return null;
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: value.trim() });
    return value.trim();
  } catch {
    return null;
  }
}

/** Today's calendar date in an IANA timezone, as YYYY-MM-DD. */
function localDate(timezone: string): string {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  return formatter.format(new Date());
}

function dateLabel(date: string): string {
  const parsed = new Date(`${date}T12:00:00Z`);
  if (Number.isNaN(parsed.getTime())) return date;
  return parsed.toLocaleDateString("en-US", {
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
    timeZone: "UTC",
  });
}

function money(value: unknown, symbol: string): string {
  const amount = asNumber(value);
  const formatted = new Intl.NumberFormat("en-US", {
    maximumFractionDigits: 0,
  }).format(Math.abs(amount));
  return `${amount < 0 ? "-" : ""}${symbol} ${formatted}`;
}

function count(value: unknown): number {
  return Math.round(asNumber(value));
}

function truncate(value: string, max: number): string {
  const trimmed = value.trim();
  return trimmed.length <= max ? trimmed : `${trimmed.slice(0, max - 1)}…`;
}

function parseModelJson(text: string): Record<string, unknown> {
  const cleaned = text
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/, "");
  try {
    const parsed = JSON.parse(cleaned);
    if (isRecord(parsed)) return parsed;
  } catch {
    // Fall through to the brace extraction below.
  }
  const start = cleaned.indexOf("{");
  const end = cleaned.lastIndexOf("}");
  if (start >= 0 && end > start) {
    try {
      const parsed = JSON.parse(cleaned.slice(start, end + 1));
      if (isRecord(parsed)) return parsed;
    } catch {
      // Fall through to the friendly error below.
    }
  }
  throw new Error("The AI returned an unreadable response.");
}

async function callGemini(
  apiKey: string,
  model: string,
  systemInstruction: string,
  userText: string,
  schema: Record<string, unknown>,
  maxOutputTokens: number,
): Promise<Record<string, unknown>> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 45_000);
  try {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${
        encodeURIComponent(model)
      }:generateContent`;

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      signal: controller.signal,
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: systemInstruction }] },
        contents: [{ role: "user", parts: [{ text: userText }] }],
        generationConfig: {
          temperature: 0.3,
          topP: 0.9,
          maxOutputTokens,
          responseMimeType: "application/json",
          responseSchema: schema,
        },
      }),
    });

    const payload = await response.json().catch(() => null);
    if (!response.ok) {
      const message = isRecord(payload) && isRecord(payload.error)
        ? String(payload.error.message ?? "")
        : "";
      throw new Error(
        message || `Gemini request failed (${response.status}).`,
      );
    }

    const blocked = isRecord(payload) && isRecord(payload.promptFeedback)
      ? payload.promptFeedback.blockReason
      : null;
    if (blocked) {
      throw new Error("The briefing was blocked by the AI safety filters.");
    }

    const candidates = isRecord(payload) && Array.isArray(payload.candidates)
      ? payload.candidates
      : [];
    const first = candidates[0];
    const content = isRecord(first) && isRecord(first.content)
      ? first.content
      : null;
    const parts = content && Array.isArray(content.parts) ? content.parts : [];
    const text = parts
      .filter((part) =>
        isRecord(part) &&
        part.thought !== true &&
        typeof part.text === "string"
      )
      .map((part) => String((part as Record<string, unknown>).text))
      .join("");

    if (!text.trim()) {
      throw new Error("The AI did not return a briefing.");
    }
    return parseModelJson(text);
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new Error("The AI request timed out.");
    }
    throw error;
  } finally {
    clearTimeout(timer);
  }
}

// ---------------------------------------------------------------------------
// Gemini prompt
// ---------------------------------------------------------------------------

const BRIEFING_SCHEMA = {
  type: "OBJECT",
  properties: {
    headline: {
      type: "STRING",
      description: "A punchy one-line headline, at most 70 characters.",
    },
    summary: {
      type: "STRING",
      description:
        "A warm 2-4 short paragraph briefing (about 80-140 words) using plain text and newlines.",
    },
    highlights: {
      type: "ARRAY",
      description: "3-5 short factual bullet points.",
      items: { type: "STRING" },
    },
    recommendations: {
      type: "ARRAY",
      description: "2-4 short, practical next actions for the owner.",
      items: { type: "STRING" },
    },
  },
  required: ["headline", "summary", "highlights", "recommendations"],
};

function briefingPrompt(
  snapshot: Metrics,
  locale: string,
  date: string,
): string {
  const bengali = locale.toLowerCase().startsWith("bn");
  return `You are the trusted business analyst inside Afraz Flow. Each evening you
write a short executive briefing for the owner of a small business.

BUSINESS SNAPSHOT (JSON, exact numbers for ${date} in the business's local time):
${JSON.stringify(snapshot)}

WRITING RULES
  * Use ONLY the supplied numbers. Never invent products, amounts, customers or
    dates. If a list is empty, say there was nothing notable.
  * Write in ${bengali ? "Bangla (bn-BD)" : "English"}.
  * Use the currency symbol from the snapshot for every money amount. Round
    sensibly; never show fake precision.
  * Be warm, direct and practical. Celebrate good days, and be calm and
    constructive on weak days. Never shame the owner.
  * headline: at most 70 characters, a specific theme of the day, not a label.
  * summary: 2-4 short paragraphs of plain text separated by newlines. Mention
    sales count and revenue, expenses and net profit, cash collected versus new
    credit, and anything urgent (low stock, reorders). Compare with the previous
    day when the numbers are meaningful.
  * highlights: 3-5 short bullet strings, each a single fact with a number.
  * recommendations: 2-4 short, concrete actions the owner can take tomorrow.
  * Do not use markdown formatting, headings, tables or emoji.

Return JSON with headline, summary, highlights, recommendations.`;
}

// ---------------------------------------------------------------------------
// Deterministic fallback narrative
// ---------------------------------------------------------------------------

function fallbackNarrative(snapshot: Metrics, locale: string): Narrative {
  const bengali = locale.toLowerCase().startsWith("bn");
  const symbol = asString(snapshot.currency_symbol, "Rs");
  const sales = isRecord(snapshot.sales) ? snapshot.sales : {};
  const expenses = isRecord(snapshot.expenses) ? snapshot.expenses : {};
  const previous = isRecord(snapshot.previous) ? snapshot.previous : {};

  const salesCount = count(sales.count);
  const revenue = asNumber(sales.revenue);
  const expenseTotal = asNumber(expenses.total);
  const netProfit = asNumber(snapshot.net_profit);
  const cashCollected = asNumber(snapshot.cash_collected);
  const newCredit = asNumber(snapshot.new_credit);
  const receivables = asNumber(snapshot.receivables);
  const payables = asNumber(snapshot.payables);
  const lowStock = asArray(snapshot.low_stock);
  const reorders = asArray(snapshot.reorders);
  const topProducts = asArray(snapshot.top_products);
  const prevRevenue = asNumber(previous.revenue);
  const prevProfit = asNumber(previous.net_profit);

  if (bengali) {
    const summary = salesCount === 0
      ? `আজ কোনো সম্পন্ন বিক্রি 기록 হয়নি। খরচ হয়েছে ${
        money(expenseTotal, symbol)
      }, নিট ফলাফল ${money(netProfit, symbol)}।`
      : `আজ ${salesCount}টি বিক্রি থেকে ${money(revenue, symbol)} আয় হয়েছে। ` +
        `খরচ ${money(expenseTotal, symbol)} বাদ দিয়ে নিট লাভ ${
          money(netProfit, symbol)
        }।`;

    const highlights = [
      `${salesCount}টি বিক্রি · ${money(revenue, symbol)}`,
      `নগদ আদায় ${money(cashCollected, symbol)} · নতুন বাকি ${
        money(newCredit, symbol)
      }`,
      `${lowStock.length}টি পণ্যের স্টক কম${
        reorders.length ? ` · ${reorders.length}টি রিঅর্ডার তৈরি` : ""
      }`,
    ];
    if (prevRevenue > 0) {
      highlights.push(
        `গতকালের আয় ছিল ${money(prevRevenue, symbol)} (নিট ${
          money(prevProfit, symbol)
        })`,
      );
    }

    const recommendations: string[] = [];
    if (lowStock.length > 0) {
      recommendations.push("কম স্টকের পণ্যগুলোর রিঅর্ডার দ্রুত নিশ্চিত করুন।");
    }
    if (receivables > 0) {
      recommendations.push(
        `গ্রাহকের কাছে ${money(receivables, symbol)} বাকি আছে — আগামীকাল কিছু আদায়ের চেষ্টা করুন।`,
      );
    }
    if (expenseTotal > revenue && salesCount > 0) {
      recommendations.push(
        "আজকের খরচ আয়ের চেয়ে বেশি ছিল; বড় খরচগুলো একবার যাচাই করুন।",
      );
    }
    if (recommendations.length === 0) {
      recommendations.push("যা ভালো চলছে তা ধরে রাখুন এবং আগামীকালের স্টক প্রস্তুত রাখুন।");
    }

    return {
      headline: salesCount === 0
        ? "আজ কোনো বিক্রি হয়নি"
        : `আজ ${money(netProfit, symbol)} নিট লাভ`,
      summary,
      highlights,
      recommendations,
    };
  }

  const summary = salesCount === 0
    ? `No completed sales were recorded today. Expenses were ${
      money(expenseTotal, symbol)
    }, leaving a net result of ${money(netProfit, symbol)}.`
    : `Today you completed ${salesCount} sale${
      salesCount === 1 ? "" : "s"
    } for ${money(revenue, symbol)} in revenue. ` +
      `After ${money(expenseTotal, symbol)} in expenses, net profit was ${
        money(netProfit, symbol)
      }.`;

  const highlights = [
    `${salesCount} sale${salesCount === 1 ? "" : "s"} · ${
      money(revenue, symbol)
    } revenue`,
    `Cash collected ${money(cashCollected, symbol)} · new credit ${
      money(newCredit, symbol)
    }`,
    `${lowStock.length} product${lowStock.length === 1 ? "" : "s"} low on stock${
      reorders.length
        ? ` · ${reorders.length} reorder${reorders.length === 1 ? "" : "s"} created`
        : ""
    }`,
  ];
  if (topProducts.length > 0) {
    const top = topProducts
      .slice(0, 3)
      .map((item) => asString(item.name, "Product"));
    highlights.push(`Best sellers: ${top.join(", ")}`);
  }
  if (prevRevenue > 0) {
    highlights.push(
      `Yesterday: ${money(prevRevenue, symbol)} revenue · ${
        money(prevProfit, symbol)
      } net profit`,
    );
  }

  const recommendations: string[] = [];
  if (lowStock.length > 0) {
    recommendations.push("Confirm the auto-reorders for low-stock products.");
  }
  if (receivables > 0) {
    recommendations.push(
      `Collect part of the ${money(receivables, symbol)} outstanding from customers.`,
    );
  }
  if (payables > 0) {
    recommendations.push(
      `Plan for ${money(payables, symbol)} payable to suppliers.`,
    );
  }
  if (expenseTotal > revenue && salesCount > 0) {
    recommendations.push("Expenses exceeded revenue today — review the largest ones.");
  }
  if (recommendations.length === 0) {
    recommendations.push("Keep the momentum going and prepare tomorrow's stock.");
  }

  return {
    headline: salesCount === 0
      ? "A quiet day with no sales"
      : `${money(netProfit, symbol)} net profit today`,
    summary,
    highlights,
    recommendations,
  };
}

const MAX_HEADLINE = 90;
const MAX_SUMMARY = 1600;
const MAX_LIST_ITEMS = 5;
const MAX_ITEM_LENGTH = 180;

function normalizeNarrative(
  raw: Record<string, unknown>,
  fallback: Narrative,
): Narrative {
  const headline = truncate(asString(raw.headline), MAX_HEADLINE);
  const summary = truncate(asString(raw.summary), MAX_SUMMARY);

  const list = (value: unknown): string[] =>
    (Array.isArray(value) ? value : [])
      .filter((item): item is string => typeof item === "string")
      .map((item) => truncate(item, MAX_ITEM_LENGTH))
      .filter((item) => item.length > 0)
      .slice(0, MAX_LIST_ITEMS);

  const highlights = list(raw.highlights);
  const recommendations = list(raw.recommendations);

  return {
    headline: headline || fallback.headline,
    summary: summary || fallback.summary,
    highlights: highlights.length > 0 ? highlights : fallback.highlights,
    recommendations: recommendations.length > 0
      ? recommendations
      : fallback.recommendations,
  };
}

// ---------------------------------------------------------------------------
// Briefing pipeline
// ---------------------------------------------------------------------------

type GenerateOptions = {
  admin: SupabaseClient;
  geminiKey?: string;
  model: string;
  tenantId: string;
  summaryDate: string;
  timezone: string;
  locale: string;
  isManual: boolean;
  createdBy: string | null;
};

async function generateBriefing(
  options: GenerateOptions,
): Promise<GeneratedBriefing> {
  const {
    admin,
    geminiKey,
    model,
    tenantId,
    summaryDate,
    timezone,
    locale,
    isManual,
    createdBy,
  } = options;

  // 1. Raise today's automatic reorder suggestions so they appear in the
  //    snapshot and in the notification the admins receive.
  const { error: reorderError } = await admin.rpc("trigger_daily_reorders", {
    p_tenant_id: tenantId,
    p_summary_date: summaryDate,
    p_timezone: timezone,
  });
  if (reorderError) {
    console.error("daily-briefing reorder failed:", reorderError.message);
  }

  // 2. Compile the exact numbers for the day.
  const { data: snapshotData, error: snapshotError } = await admin.rpc(
    "build_daily_business_snapshot",
    {
      p_tenant_id: tenantId,
      p_summary_date: summaryDate,
      p_timezone: timezone,
    },
  );
  if (snapshotError) {
    throw new Error(`Could not build the business snapshot: ${snapshotError.message}`);
  }
  if (!isRecord(snapshotData)) {
    throw new Error("The business snapshot was empty.");
  }
  const snapshot = snapshotData as Metrics;

  // 3. Ask Gemini for the narrative. If the key is missing or the model fails,
  //    a deterministic narrative is saved instead so the feature never breaks.
  const fallback = fallbackNarrative(snapshot, locale);
  let narrative = fallback;
  let source: "gemini" | "fallback" = "fallback";
  let usedModel: string | null = null;

  if (geminiKey) {
    try {
      const raw = await callGemini(
        geminiKey,
        model,
        briefingPrompt(snapshot, locale, summaryDate),
        "Write today's executive briefing from the snapshot above.",
        BRIEFING_SCHEMA,
        2048,
      );
      narrative = normalizeNarrative(raw, fallback);
      source = "gemini";
      usedModel = model;
    } catch (error) {
      console.error(
        "daily-briefing Gemini failed, using fallback:",
        error instanceof Error ? error.message : String(error),
      );
    }
  }

  // 4. Persist the snapshot + narrative. A scheduled run supersedes a manual
  //    preview for the same day, so the row is always upserted.
  const { data: summaryRow, error: summaryError } = await admin
    .from("daily_summaries")
    .upsert(
      {
        tenant_id: tenantId,
        summary_date: summaryDate,
        timezone,
        headline: narrative.headline,
        summary: narrative.summary,
        highlights: narrative.highlights,
        recommendations: narrative.recommendations,
        metrics: snapshot,
        source,
        model: usedModel,
        is_manual: isManual,
        generated_at: new Date().toISOString(),
        created_by: createdBy,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "tenant_id,summary_date" },
    )
    .select()
    .single();

  if (summaryError || !isRecord(summaryRow)) {
    throw new Error(
      `Could not save the briefing: ${summaryError?.message ?? "unknown error"}`,
    );
  }

  // 5. Notify every active admin of the business. The dedupe key keeps one
  //    notification per business day even if the function runs again.
  const { data: admins, error: adminsError } = await admin
    .from("tenant_members")
    .select("user_id")
    .eq("tenant_id", tenantId)
    .eq("role", "admin")
    .eq("is_active", true);

  if (adminsError) {
    console.error("daily-briefing admin lookup failed:", adminsError.message);
  }

  const recipients = (Array.isArray(admins) ? admins : [])
    .filter(isRecord)
    .map((row) => asString(row.user_id))
    .filter((userId) => UUID_PATTERN.test(userId));

  if (recipients.length > 0) {
    const body =
      `Your Daily Business Briefing for ${dateLabel(summaryDate)} is ready. Tap to view.`;
    const dedupeKey = `daily_briefing:${tenantId}:${summaryDate}`;

    const { error: notificationError } = await admin
      .from("app_notifications")
      .upsert(
        recipients.map((userId) => ({
          tenant_id: tenantId,
          user_id: userId,
          title: "Daily AI Briefing",
          body,
          kind: "daily_briefing",
          reference_id: asString(summaryRow.id),
          dedupe_key: dedupeKey,
        })),
        { onConflict: "user_id,dedupe_key", ignoreDuplicates: true },
      );

    if (notificationError) {
      console.error(
        "daily-briefing notification failed:",
        notificationError.message,
      );
    }
  }

  return {
    summary: summaryRow,
    notifications: recipients.length,
    mode: isManual ? "manual" : "scheduled",
  };
}

// ---------------------------------------------------------------------------
// HTTP handler
// ---------------------------------------------------------------------------

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
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const geminiKey = Deno.env.get("GEMINI_API_KEY")?.trim() || undefined;
    const model = Deno.env.get("GEMINI_MODEL")?.trim() || "gemini-3.6-flash";

    if (!supabaseUrl || !anonKey || !serviceKey) {
      return json({ error: "The function is not configured." }, 500);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ error: "Missing authorization header" }, 401);
    }
    const accessToken = authHeader.slice("Bearer ".length).trim();
    if (!accessToken) {
      return json({ error: "Missing authorization token" }, 401);
    }

    const payload = (await req.json().catch(() => ({}))) as BriefingPayload;
    const locale =
      payload.locale?.trim() ||
      req.headers.get("x-app-locale")?.trim() ||
      "en-US";

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // -----------------------------------------------------------------------
    // Scheduled mode
    // -----------------------------------------------------------------------
    if (accessToken === serviceKey) {
      const { data: dueRows, error: dueError } = await admin.rpc(
        "list_due_daily_summaries",
        { p_limit: MAX_BATCH },
      );
      if (dueError) {
        return json({ error: dueError.message }, 500);
      }

      const due = (Array.isArray(dueRows) ? dueRows : [])
        .filter(isRecord) as DueBriefing[];

      const results: Record<string, unknown>[] = [];
      for (const row of due) {
        const tenantId = asString(row.tenant_id);
        const summaryDate = asString(row.summary_date);
        const timezone = validTimezone(row.briefing_timezone) ?? "UTC";
        if (!UUID_PATTERN.test(tenantId) || !DATE_PATTERN.test(summaryDate)) {
          continue;
        }
        try {
          const generated = await generateBriefing({
            admin,
            geminiKey,
            model,
            tenantId,
            summaryDate,
            timezone,
            locale,
            isManual: false,
            createdBy: null,
          });
          results.push({
            tenant_id: tenantId,
            tenant_name: row.tenant_name,
            summary_date: summaryDate,
            source: generated.summary.source,
            notifications: generated.notifications,
            ok: true,
          });
        } catch (error) {
          const message = error instanceof Error ? error.message : String(error);
          console.error(`daily-briefing failed for ${tenantId}:`, message);
          results.push({
            tenant_id: tenantId,
            summary_date: summaryDate,
            ok: false,
            error: message,
          });
        }
      }

      return json({
        mode: "batch",
        processed: results.length,
        succeeded: results.filter((item) => item.ok === true).length,
        failed: results.filter((item) => item.ok !== true).length,
        results,
        generated_at: new Date().toISOString(),
      });
    }

    // -----------------------------------------------------------------------
    // Manual mode — an admin taps "Generate briefing"
    // -----------------------------------------------------------------------
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

    const tenantId = payload.tenant_id?.trim() ?? "";
    if (!UUID_PATTERN.test(tenantId)) {
      return json({ error: "A valid tenant_id is required" }, 400);
    }

    const { data: membership, error: membershipError } = await callerClient
      .from("tenant_members")
      .select("role, is_active")
      .eq("tenant_id", tenantId)
      .eq("user_id", caller.id)
      .maybeSingle();

    if (membershipError) {
      return json({ error: membershipError.message }, 500);
    }
    if (!membership || !membership.is_active || membership.role !== "admin") {
      return json(
        { error: "Only an active admin can generate the daily briefing." },
        403,
      );
    }

    const { data: tenantRow, error: tenantError } = await admin
      .from("tenants")
      .select("name, currency, currency_symbol, daily_briefing_timezone")
      .eq("id", tenantId)
      .maybeSingle();

    if (tenantError) {
      return json({ error: tenantError.message }, 500);
    }
    if (!isRecord(tenantRow)) {
      return json({ error: "Business not found" }, 404);
    }

    const timezone =
      validTimezone(payload.timezone) ??
      validTimezone(tenantRow.daily_briefing_timezone) ??
      "UTC";

    const requestedDate = payload.summary_date?.trim() ?? "";
    const summaryDate = DATE_PATTERN.test(requestedDate)
      ? requestedDate
      : localDate(timezone);

    const generated = await generateBriefing({
      admin,
      geminiKey,
      model,
      tenantId,
      summaryDate,
      timezone,
      locale,
      isManual: true,
      createdBy: caller.id,
    });

    return json({
      ...generated.summary,
      mode: "manual",
      notifications: generated.notifications,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("daily-briefing error:", message);
    return json({ error: message }, 500);
  }
});
