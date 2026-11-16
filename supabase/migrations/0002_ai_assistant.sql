-- Afraz Flow — AI Business Assistant read-only query gateway.
--
-- The `ai-assistant` Edge Function asks Gemini to translate an admin's question
-- into a single SELECT statement, then runs it through this RPC using the
-- caller's own JWT.
--
-- Why this is safe
-- ----------------
-- 1. `security invoker` means the dynamic statement runs as the signed-in user,
--    so every existing RLS policy still applies. The assistant can never read
--    rows outside the caller's tenant memberships.
-- 2. Only active admins of the requested tenant may call the function.
-- 3. The SQL text is validated in Postgres as well as in the Edge Function:
--    only a single SELECT/WITH statement is accepted, comments/semicolons and
--    every write/data-definition keyword are rejected, dangerous functions and
--    non-application schemas are blocked, and the statement must be explicitly
--    scoped to the current tenant id.
-- 4. Results are capped at 200 rows and the statement times out after 8s.
--
-- Deploy with:
--   supabase db push
-- (or paste this file into the SQL editor after 0001_init.sql).

create or replace function public.ai_assistant_query(
  p_tenant_id uuid,
  p_sql text
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $function$
declare
  v_sql text := btrim(coalesce(p_sql, ''));
  v_rows jsonb;
  v_count integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_tenant_id is null then
    raise exception 'A tenant is required';
  end if;

  if not public.has_tenant_role(p_tenant_id, array['admin']::text[]) then
    raise exception 'Only an active admin can use the AI assistant';
  end if;

  if length(v_sql) < 12 or length(v_sql) > 12000 then
    raise exception 'The generated query length is not acceptable';
  end if;

  -- Exactly one statement. Trailing semicolons are tolerated, any other
  -- semicolon is not.
  v_sql := regexp_replace(v_sql, '\s*;\s*$', '');
  if position(';' in v_sql) > 0 then
    raise exception 'Only one statement is allowed';
  end if;

  -- Comments and dollar quoting make validation ambiguous, so reject them.
  if position('--' in v_sql) > 0
     or position('/*' in v_sql) > 0
     or position('$$' in v_sql) > 0 then
    raise exception 'Comments are not allowed in assistant queries';
  end if;

  -- Read-only statements only.
  if v_sql !~* '^(select|with)\y' then
    raise exception 'Only SELECT statements are allowed';
  end if;

  -- Block every form of write, DDL, transaction control and data movement.
  if v_sql ~* '\y(insert|update|delete|merge|truncate|drop|alter|create|grant|revoke|copy|call|execute|do|vacuum|analyze|cluster|reindex|refresh|listen|notify|unlisten|set|reset|begin|commit|rollback|savepoint|release|prepare|deallocate|discard|lock|into|load)\y' then
    raise exception 'Write and data-definition statements are not allowed';
  end if;

  -- Row locks are not needed by the assistant.
  if v_sql ~* '\yfor\s+(no\s+key\s+)?update\y'
     or v_sql ~* '\yfor\s+(key\s+)?share\y' then
    raise exception 'Row locking is not allowed';
  end if;

  -- Block schemas and functions that could expose credentials, files or
  -- perform writes outside RLS.
  if v_sql ~* '\y(auth|storage|vault|pg_catalog|information_schema|pg_toast|supabase_migrations|realtime|graphql|extensions)\s*\.' then
    raise exception 'That schema is not available to the assistant';
  end if;
  if v_sql ~* '\y(pg_|dblink|lo_|txid_|query_to_xml|set_config|current_setting|nextval|setval|currval|ai_assistant_query|checkout_sale|adjust_stock|record_ledger_entry|create_organization)\w*' then
    raise exception 'That function is not available to the assistant';
  end if;

  -- Defence in depth for users who belong to more than one business: the
  -- generated statement must filter by the requested tenant, not merely
  -- mention it in a string literal.
  if v_sql !~* ('\y(tenant_id|id)\s*=\s*''' || p_tenant_id::text || '''') then
    raise exception 'The query must be scoped to the current business';
  end if;

  perform set_config('statement_timeout', '8000', true);

  execute format(
    'select coalesce(jsonb_agg(to_jsonb(ai_row)), ''[]''::jsonb), count(*)::int '
    'from (select * from (%s) as ai_src limit 200) as ai_row',
    v_sql
  )
  into v_rows, v_count;

  return jsonb_build_object(
    'rows', v_rows,
    'truncated', v_count >= 200
  );
end;
$function$;

revoke all on function public.ai_assistant_query(uuid, text)
  from public, anon, authenticated;
grant execute on function public.ai_assistant_query(uuid, text)
  to authenticated;

comment on function public.ai_assistant_query(uuid, text) is
  'Read-only, RLS-enforced query gateway used by the Gemini AI assistant. Admin only.';
