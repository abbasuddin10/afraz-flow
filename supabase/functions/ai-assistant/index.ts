// Supabase Edge Function: ai-assistant
//
// A Gemini-powered business analyst for Afraz Flow admins.
//
// Flow
// ----
// 1. Verify the caller's Supabase JWT and require an active `admin` membership
//    of the requested tenant.
// 2. Send the question, conversation history and the database schema to Gemini.
//    Gemini returns either a short direct answer or one read-only SELECT.
// 3. Validate the SQL again on the server, then execute it through the
//    `ai_assistant_query` Postgres RPC using the caller's JWT. That RPC is
//    SECURITY INVOKER, so Row Level Security applies exactly as it does for the
//    normal Flutter client.
// 4. Send the result rows back to Gemini to produce a friendly answer in the
//    user's language, plus a few suggested follow-up questions.
//
// The model never holds database credentials, and the service-role key is not
// used for data access.
//
// Deploy:
//   supabase functions deploy ai-assistant
//   supabase secrets set GEMINI_API_KEY=...
// Optional:
//   supabase secrets set GEMINI_MODEL=gemini-3.6-flash

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { assertSafeSql, utcOffsetLabel } from "./sql_guard.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type AssistantTurn = {
  role?: string;
  content?: string;
};

type AssistantPayload = {
  tenant_id?: string;
  message?: string;
  history?: AssistantTurn[];
  today?: string;
  timezone?: string;
  utc_offset_minutes?: number;
  locale?: string;
};

type TenantContext = {
  name?: string;
  business_type?: string;
  currency?: string;
  currency_symbol?: string;
};

type QueryResult = {
  rows: Record<string, unknown>[];
  truncated: boolean;
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const MAX_MESSAGE_LENGTH = 2000;
const MAX_HISTORY_TURNS = 8;
const MAX_ROWS = 200;

// ---------------------------------------------------------------------------
// Schema context handed to Gemini
// ---------------------------------------------------------------------------

const SCHEMA_CONTEXT = `
APPLICATION SCHEMA (PostgreSQL / Supabase, all tables in schema public)

public.tenants
  id uuid, name text, business_type text, currency text, currency_symbol text,
  tax_rate numeric, low_stock_threshold integer, phone text, email text,
  address text, created_at timestamptz

public.profiles
  id uuid (= auth user id), email text, full_name text, phone text,
  avatar_url text, created_at timestamptz

public.tenant_members
  id uuid, tenant_id uuid, user_id uuid, role text ('admin' | 'manager' | 'cashier'),
  is_active boolean, created_at timestamptz

public.products
  id uuid, tenant_id uuid, name text, sku text, barcode text, category text,
  unit text, cost_price numeric, sale_price numeric, stock_qty numeric,
  low_stock_threshold integer, is_active boolean, image_url text,
  created_at timestamptz, updated_at timestamptz

public.stock_movements
  id uuid, tenant_id uuid, product_id uuid, product_name text,
  movement_type text ('in' | 'out' | 'adjustment'), quantity numeric,
  note text, reference text, created_by uuid, created_at timestamptz

public.ledger_accounts
  id uuid, tenant_id uuid, name text, account_type text ('customer' | 'supplier'),
  opening_balance numeric, balance numeric, phone text, email text, address text,
  created_at timestamptz, updated_at timestamptz

public.ledger_entries
  id uuid, tenant_id uuid, account_id uuid,
  entry_type text ('charge' | 'payment'), amount numeric,
  entry_date date, description text, reference text, created_at timestamptz

public.sales
  id uuid, tenant_id uuid, invoice_no text, account_id uuid,
  customer_name text, subtotal numeric, discount numeric, tax numeric,
  total numeric, paid_amount numeric, due_amount numeric,
  payment_method text ('cash' | 'card' | 'bank' | 'credit'),
  status text ('completed' | 'refunded' | 'voided'), note text,
  created_by uuid, created_at timestamptz, updated_at timestamptz

public.sale_items
  id text, tenant_id uuid, sale_id uuid, product_id uuid, product_name text,
  sku text, quantity numeric, unit_price numeric, cost_price numeric,
  line_total numeric, created_at timestamptz

public.expenses
  id uuid, tenant_id uuid, category text, description text, amount numeric,
  payment_method text, expense_date date, reference text, created_by uuid,
  created_at timestamptz

public.courier_orders
  id uuid, tenant_id uuid, order_no text, sale_id uuid, customer_name text,
  customer_phone text, address text, city text, courier_partner text,
  tracking_number text,
  status text ('pending' | 'shipped' | 'delivered' | 'returned' | 'cancelled'),
  cod_amount numeric, cod_collected boolean, shipping_fee numeric, notes text,
  dispatched_at timestamptz, delivered_at timestamptz,
  created_at timestamptz, updated_at timestamptz

public.courier_events
  id uuid, tenant_id uuid, courier_order_id uuid, status text, note text,
  created_at timestamptz

RELATIONSHIPS
  tenant_members.tenant_id -> tenants.id
  tenant_members.user_id -> profiles.id
  products.tenant_id -> tenants.id
  stock_movements.product_id -> products.id
  ledger_accounts.tenant_id -> tenants.id
  ledger_entries.account_id -> ledger_accounts.id
  sales.account_id -> ledger_accounts.id
  sale_items.sale_id -> sales.id
  sale_items.product_id -> products.id
  courier_orders.sale_id -> sales.id
  courier_events.courier_order_id -> courier_orders.id

BUSINESS RULES
  * Every business table carries tenant_id. Always filter it explicitly.
  * Revenue = SUM(sales.total) for sales with status = 'completed'.
  * Cost of goods = SUM(sale_items.cost_price * sale_items.quantity) for completed sales.
  * Gross profit = SUM(sale_items.line_total - sale_items.cost_price * sale_items.quantity)
    for completed sales. Net profit = gross profit - SUM(expenses.amount) for the period.
  * Receivables = SUM(ledger_accounts.balance) where account_type = 'customer'.
    Payables = SUM(ledger_accounts.balance) where account_type = 'supplier'.
  * sales.due_amount is the unpaid part of a sale. paid_amount is what was collected.
  * Stock on hand is products.stock_qty. Low stock means
    stock_qty <= low_stock_threshold. Prefer is_active = true unless the user asks
    for archived products.
  * For product names use case-insensitive matching, e.g. name ILIKE '%noodle%'.
  * courier_orders.status = 'pending' means not dispatched yet.
  * ledger_entries.entry_type = 'charge' increases what a customer owes;
    'payment' reduces it.
`;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isoDate(value: unknown): string {
  if (typeof value === "string") {
    const trimmed = value.trim();
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(trimmed);
    if (match) {
      const year = Number(match[1]);
      const month = Number(match[2]);
      const day = Number(match[3]);
      const parsed = new Date(Date.UTC(year, month - 1, day));
      if (
        parsed.getUTCFullYear() === year &&
        parsed.getUTCMonth() === month - 1 &&
        parsed.getUTCDate() === day
      ) {
        return trimmed;
      }
    }
  }
  return new Date().toISOString().slice(0, 10);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
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
  contents: unknown[],
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
        contents,
        generationConfig: {
          temperature: 0.15,
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
      throw new Error("That question was blocked by the AI safety filters.");
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
      throw new Error("The AI did not return an answer. Please try again.");
    }
    return parseModelJson(text);
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new Error("The AI request timed out. Please try again.");
    }
    throw error;
  } finally {
    clearTimeout(timer);
  }
}

// ---------------------------------------------------------------------------
// Gemini prompts
// ---------------------------------------------------------------------------

function plannerPrompt(
  tenantId: string,
  tenant: TenantContext,
  today: string,
  timezoneOffset: string,
  locale: string,
): string {
  return `You are the data analyst inside Afraz Flow, a multi-tenant business
management app. You translate an administrator's natural-language question into
ONE safe, read-only PostgreSQL query.

CURRENT BUSINESS
  tenant_id: ${tenantId}
  business name: ${tenant?.name ?? "Unknown"}
  business type: ${tenant?.business_type ?? "Other"}
  currency: ${tenant?.currency ?? "PKR"} (symbol: ${tenant?.currency_symbol ?? "Rs"})
  today's date (business local time): ${today}
  UTC offset for business local time: ${timezoneOffset}
  app locale: ${locale}

${SCHEMA_CONTEXT}

HARD OUTPUT RULES
  * Return JSON with: needs_data (boolean), sql (string), direct_answer (string),
    follow_ups (array of 2-3 short strings).
  * If the question is a greeting, thanks, a question about your capabilities, or
    otherwise needs no live data, set needs_data=false, sql="", and put a short,
    friendly direct_answer in the user's language. Also include 2-3 suggested
    business questions in follow_ups, in the same language.
  * If live data is needed, set needs_data=true, direct_answer="", follow_ups=[],
    and return exactly one SELECT (or WITH ... SELECT) statement in sql.
  * Never use INSERT, UPDATE, DELETE, DDL, COPY, CALL, stored procedures,
    comments, or more than one statement. Never end with a semicolon.
  * The statement MUST include a literal equality filter on the current tenant:
    either tenant_id = '${tenantId}' or, for the tenants table, id = '${tenantId}'.
    Do not use parameters or placeholders.
  * Only reference tables and columns from the schema above. Never query auth,
    storage, vault, pg_catalog or information_schema.
  * Use today's date literal '${today}' instead of current_date so the answer
    follows the business's local day. For timestamp columns (created_at,
    updated_at, dispatched_at, delivered_at) convert to local time first, e.g.
    (sales.created_at AT TIME ZONE '${timezoneOffset}')::date = '${today}'.
    Date columns such as expense_date and entry_date are already calendar dates.
  * Return at most 200 rows. Aggregate where possible, and give descriptive
    snake_case column aliases (for example total_profit, stock_qty, product_name).
  * For product name searches use ILIKE '%term%'. If the user uses a local or
    transliterated product name, search for the most likely English/Bangla term.
  * Count only status='completed' sales as revenue. Exclude refunded and voided
    sales unless the question explicitly asks about them.
  * If the question is ambiguous, choose the most useful interpretation and answer
    it rather than refusing.

ANSWER LANGUAGE
  Answer in the same language as the administrator's question (English, Bangla,
  or a mixed style). Currency amounts should be described with the currency
  symbol above.`;
}

const PLANNER_SCHEMA = {
  type: "OBJECT",
  properties: {
    needs_data: {
      type: "BOOLEAN",
      description: "True when the question needs live business data.",
    },
    sql: {
      type: "STRING",
      description:
        "A single read-only SELECT/WITH statement, or an empty string when needs_data is false.",
    },
    direct_answer: {
      type: "STRING",
      description:
        "A short friendly answer when no data is needed, otherwise an empty string.",
    },
    follow_ups: {
      type: "ARRAY",
      description:
        "2-3 suggested questions in the user's language when no data is needed.",
      items: { type: "STRING" },
    },
  },
  required: ["needs_data", "sql", "direct_answer", "follow_ups"],
};

function summarizerPrompt(
  tenant: TenantContext,
  today: string,
): string {
  return `You are the same warm, concise business assistant inside Afraz Flow.
You are given the administrator's question and the exact rows returned from
their own business database (already filtered by Row Level Security).

RESPONSE RULES
  * Answer in the SAME language as the administrator's question. If they write in
    Bangla, reply in Bangla; if they mix English and Bangla, you may mix naturally.
  * Use ONLY the supplied rows. Never invent products, amounts, dates or counts.
  * Be conversational and practical: a short opening sentence, then the key
    numbers. Use "-" bullet points when listing more than two items. Do not use
    markdown tables (the app renders the rows as a real table).
  * Use the business currency symbol ${tenant?.currency_symbol ?? "Rs"} for money.
    Round sensibly; do not add fake precision.
  * If the rows are empty, say clearly that nothing matched and suggest a small
    refinement (for example a different product name or date range).
  * Keep the answer under 140 words unless a short list is genuinely needed.
  * Provide 2-3 follow-up questions the admin is likely to ask next, in the same
    language. Keep each under 60 characters.
  * Today's local date is ${today}.

Return JSON with: answer (string) and follow_ups (array of strings).`;
}

const SUMMARIZER_SCHEMA = {
  type: "OBJECT",
  properties: {
    answer: { type: "STRING" },
    follow_ups: {
      type: "ARRAY",
      items: { type: "STRING" },
    },
  },
  required: ["answer", "follow_ups"],
};

// ---------------------------------------------------------------------------
// Small utilities
// ---------------------------------------------------------------------------

function compactRows(rows: Record<string, unknown>[]): Record<string, unknown>[] {
  return rows.slice(0, 100).map((row) => {
    const compact: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(row)) {
      compact[key] = typeof value === "string" && value.length > 400
        ? `${value.slice(0, 400)}…`
        : value;
    }
    return compact;
  });
}

function fallbackAnswer(
  rows: Record<string, unknown>[],
  locale: string,
): string {
  const bengali = locale.toLowerCase().startsWith("bn");
  if (rows.length === 0) {
    return bengali
      ? "এই প্রশ্নের জন্য কোনো মিলে যাওয়া তথ্য পাওয়া যায়নি। অন্য নাম বা তারিখ দিয়ে আবার চেষ্টা করুন।"
      : "I couldn't find any matching data for that question. Try a different product name or date range.";
  }
  return bengali
    ? "আপনার ব্যবসার তথ্য থেকে ফলাফল নিচে দেওয়া হলো।"
    : "Here is what I found in your business data.";
}

function extractRows(result: unknown): QueryResult {
  if (isRecord(result)) {
    const rows = Array.isArray(result.rows) ? result.rows : [];
    return {
      rows: rows.filter(isRecord) as Record<string, unknown>[],
      truncated: result.truncated === true,
    };
  }
  if (Array.isArray(result)) {
    return {
      rows: result.filter(isRecord) as Record<string, unknown>[],
      truncated: result.length >= MAX_ROWS,
    };
  }
  return { rows: [], truncated: false };
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
    const geminiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
    const model =
      Deno.env.get("GEMINI_MODEL")?.trim() || "gemini-3.6-flash";

    if (!supabaseUrl || !anonKey) {
      return json({ error: "The function is not configured." }, 500);
    }
    if (!geminiKey) {
      return json(
        {
          error:
            "The AI assistant is not configured. Set the GEMINI_API_KEY secret for this function.",
        },
        500,
      );
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ error: "Missing authorization header" }, 401);
    }
    const accessToken = authHeader.slice("Bearer ".length).trim();
    if (!accessToken) {
      return json({ error: "Missing authorization token" }, 401);
    }

    // The caller client carries the user's JWT. It is used for every database
    // read, so RLS — not the service-role key — is the security boundary.
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

    const payload = (await req.json().catch(() => ({}))) as AssistantPayload;
    const tenantId = payload.tenant_id?.trim() ?? "";
    const message = payload.message?.trim() ?? "";

    if (!UUID_PATTERN.test(tenantId)) {
      return json({ error: "A valid tenant_id is required" }, 400);
    }
    if (!message) {
      return json({ error: "Ask a question first." }, 400);
    }
    if (message.length > MAX_MESSAGE_LENGTH) {
      return json(
        { error: "That question is too long. Please keep it under 2,000 characters." },
        400,
      );
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
        { error: "Only an active admin can use the AI assistant." },
        403,
      );
    }

    const { data: tenantRow } = await callerClient
      .from("tenants")
      .select("name, business_type, currency, currency_symbol")
      .eq("id", tenantId)
      .maybeSingle();

    const tenant: TenantContext = isRecord(tenantRow) ? tenantRow : {};
    const today = isoDate(payload.today);
    const timezoneOffset = utcOffsetLabel(payload.utc_offset_minutes);
    const locale =
      payload.locale?.trim() ||
      req.headers.get("x-app-locale")?.trim() ||
      "en-US";

    const history = (Array.isArray(payload.history) ? payload.history : [])
      .filter((turn) =>
        turn &&
        typeof turn.content === "string" &&
        turn.content.trim().length > 0
      )
      .slice(-MAX_HISTORY_TURNS)
      .map((turn) => ({
        role: turn.role === "assistant" ? "model" : "user",
        parts: [{ text: turn.content!.trim().slice(0, MAX_MESSAGE_LENGTH) }],
      }));

    const contents = [
      ...history,
      { role: "user", parts: [{ text: message }] },
    ];

    const plan = await callGemini(
      geminiKey,
      model,
      plannerPrompt(tenantId, tenant, today, timezoneOffset, locale),
      contents,
      PLANNER_SCHEMA,
      2048,
    );

    const needsData = plan.needs_data === true;
    const directAnswer =
      typeof plan.direct_answer === "string" ? plan.direct_answer.trim() : "";

    if (!needsData) {
      const planFollowUps = Array.isArray(plan.follow_ups)
        ? plan.follow_ups
          .filter((item): item is string => typeof item === "string")
          .map((item) => item.trim())
          .filter((item) => item.length > 0)
          .slice(0, 3)
        : [];

      return json({
        answer:
          directAnswer ||
          "I can look up stock, sales, profit, customer dues, expenses and courier data for your business. What would you like to know?",
        sql: null,
        columns: [],
        rows: [],
        row_count: 0,
        truncated: false,
        follow_ups: planFollowUps.length > 0
          ? planFollowUps
          : [
            "What is today's total profit?",
            "Which products are low on stock?",
            "Show pending courier orders",
          ],
      });
    }

    if (typeof plan.sql !== "string" || !plan.sql.trim()) {
      return json(
        { error: "The assistant could not build a query for that question. Try rephrasing it." },
        422,
      );
    }

    const sql = assertSafeSql(plan.sql, tenantId);

    // Execute with the caller's JWT through the RLS-enforcing RPC.
    const { data: queryResult, error: queryError } = await callerClient.rpc(
      "ai_assistant_query",
      { p_tenant_id: tenantId, p_sql: sql },
    );

    if (queryError) {
      console.error("ai-assistant query failed:", queryError.message);
      return json(
        {
          error:
            "I couldn't run that query safely. Try asking in a slightly different way.",
          detail: queryError.message,
        },
        400,
      );
    }

    const { rows, truncated } = extractRows(queryResult);
    const columns = rows.length > 0 ? Object.keys(rows[0]) : [];

    const summary = await callGemini(
      geminiKey,
      model,
      summarizerPrompt(tenant, today),
      [
        {
          role: "user",
          parts: [
            {
              text: [
                `ADMIN QUESTION:\n${message}`,
                `ROWS (${rows.length} returned${truncated ? ", truncated at 200" : ""}):`,
                JSON.stringify(compactRows(rows)),
                rows.length === 0
                  ? "No rows matched. Explain that gently and suggest a refinement."
                  : "Summarise these rows for the admin.",
              ].join("\n\n"),
            },
          ],
        },
      ],
      SUMMARIZER_SCHEMA,
      2048,
    );

    const answer = typeof summary.answer === "string"
      ? summary.answer.trim()
      : "";
    const followUps = Array.isArray(summary.follow_ups)
      ? summary.follow_ups
        .filter((item): item is string => typeof item === "string")
        .map((item) => item.trim())
        .filter((item) => item.length > 0)
        .slice(0, 3)
      : [];

    return json({
      answer: answer || fallbackAnswer(rows, locale),
      sql,
      columns,
      rows,
      row_count: rows.length,
      truncated,
      follow_ups: followUps,
      generated_at: new Date().toISOString(),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("ai-assistant error:", message);
    return json({ error: message }, 500);
  }
});
