// Read-only SQL guard shared by the ai-assistant Edge Function.
//
// This mirrors `public.ai_assistant_query` in 0002_ai_assistant.sql. The
// Postgres function is the final authority; this module catches bad model
// output before it ever reaches the database.

export const MAX_SQL_LENGTH = 12_000;

const WRITE_KEYWORDS =
  /\b(insert|update|delete|merge|truncate|drop|alter|create|grant|revoke|copy|call|execute|do|vacuum|analyze|cluster|reindex|refresh|listen|notify|unlisten|set|reset|begin|commit|rollback|savepoint|release|prepare|deallocate|discard|lock|into|load)\b/i;

const LOCK_CLAUSE =
  /\bfor\s+(no\s+key\s+)?update\b|\bfor\s+(key\s+)?share\b/i;

const FORBIDDEN_SCHEMAS =
  /\b(auth|storage|vault|pg_catalog|information_schema|pg_toast|supabase_migrations|realtime|graphql|extensions)\s*\./i;

const FORBIDDEN_FUNCTIONS =
  /\b(pg_|dblink|lo_|txid_|query_to_xml|set_config|current_setting|nextval|setval|currval|ai_assistant_query|checkout_sale|adjust_stock|record_ledger_entry|create_organization)\w*/i;

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Validates and normalises a model-generated SQL statement.
 *
 * The accepted grammar is deliberately narrow: one SELECT/WITH statement with
 * no comments, no semicolons, no row locks, no write/DDL keywords, no protected
 * schemas or functions, and a literal equality filter on the current tenant.
 */
export function assertSafeSql(rawSql: string, tenantId: string): string {
  let sql = rawSql
    .trim()
    .replace(/^```(?:sql)?\s*/i, "")
    .replace(/\s*```$/, "")
    .trim();

  sql = sql.replace(/\s*;\s*$/, "");

  if (sql.length < 12 || sql.length > MAX_SQL_LENGTH) {
    throw new Error("The assistant generated an invalid query.");
  }
  if (sql.includes(";")) {
    throw new Error("The assistant tried to run more than one statement.");
  }
  if (sql.includes("--") || sql.includes("/*") || sql.includes("$$")) {
    throw new Error("The assistant generated an unsupported query.");
  }
  if (!/^(select|with)\b/i.test(sql)) {
    throw new Error("Only read-only SELECT queries are allowed.");
  }
  if (WRITE_KEYWORDS.test(sql)) {
    throw new Error("The assistant tried to modify data, which is not allowed.");
  }
  if (LOCK_CLAUSE.test(sql)) {
    throw new Error("The assistant tried to lock data, which is not allowed.");
  }
  if (FORBIDDEN_SCHEMAS.test(sql)) {
    throw new Error("The assistant tried to access a protected schema.");
  }
  if (FORBIDDEN_FUNCTIONS.test(sql)) {
    throw new Error("The assistant tried to call a protected function.");
  }

  const tenantFilter = new RegExp(
    `\\b(tenant_id|id)\\s*=\\s*'${escapeRegExp(tenantId)}'`,
    "i",
  );
  if (!tenantFilter.test(sql)) {
    throw new Error(
      "The assistant did not scope the query to your business. Please rephrase.",
    );
  }
  return sql;
}

/**
 * Formats the browser's UTC offset as a PostgreSQL-safe label such as +06:00.
 * This lets generated SQL group timestamptz values by the admin's local day
 * instead of the database's UTC day.
 */
export function utcOffsetLabel(value: unknown): string {
  const raw = typeof value === "number" && Number.isFinite(value) ? value : 0;
  const minutes = Math.max(-720, Math.min(840, Math.round(raw)));
  const sign = minutes >= 0 ? "+" : "-";
  const absolute = Math.abs(minutes);
  const hours = String(Math.floor(absolute / 60)).padStart(2, "0");
  const rest = String(absolute % 60).padStart(2, "0");
  return `${sign}${hours}:${rest}`;
}
