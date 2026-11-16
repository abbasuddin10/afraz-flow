-- Afraz Flow — Daily Executive Summary and in-app briefings.
--
-- Design
-- ------
-- * Every tenant stores its preferred briefing time and IANA timezone.
-- * `daily_summaries` keeps one structured snapshot + narrative per business day.
-- * `inventory_reorders` records the automatic reorder suggestions raised while
--   a briefing is built (idempotent per product per day).
-- * `app_notifications` powers the in-app bell and Supabase Realtime. Rows are
--   addressed to individual admin profiles, so RLS can keep them private.
--
-- The scheduled work is performed by the `daily-briefing` Edge Function using
-- the service role. Admins can also generate today's briefing on demand from
-- the Flutter app; the function still verifies their membership.
--
-- Deploy with:
--   supabase db push
-- (or paste this file into the SQL editor after 0002_ai_assistant.sql).

-- ---------------------------------------------------------------------------
-- Tenant briefing preferences
-- ---------------------------------------------------------------------------

alter table public.tenants
  add column if not exists daily_briefing_enabled boolean not null default true,
  add column if not exists daily_briefing_time time not null default '22:00',
  add column if not exists daily_briefing_timezone text not null default 'Asia/Karachi';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'tenants_daily_briefing_timezone_check'
      and conrelid = 'public.tenants'::regclass
  ) then
    alter table public.tenants
      add constraint tenants_daily_briefing_timezone_check
      check (length(trim(daily_briefing_timezone)) > 0);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.daily_summaries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  summary_date date not null,
  timezone text not null default 'UTC',
  headline text not null default '',
  summary text not null default '',
  highlights jsonb not null default '[]'::jsonb,
  recommendations jsonb not null default '[]'::jsonb,
  metrics jsonb not null default '{}'::jsonb,
  source text not null default 'gemini'
    check (source in ('gemini', 'fallback', 'local')),
  model text,
  is_manual boolean not null default false,
  generated_at timestamptz not null default now(),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, summary_date)
);

create index if not exists daily_summaries_tenant_date_idx
  on public.daily_summaries (tenant_id, summary_date desc);

create table if not exists public.app_notifications (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null default '',
  body text not null default '',
  kind text not null default 'daily_briefing',
  reference_id uuid,
  dedupe_key text not null,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, dedupe_key)
);

create index if not exists app_notifications_user_created_idx
  on public.app_notifications (user_id, created_at desc);
create index if not exists app_notifications_tenant_created_idx
  on public.app_notifications (tenant_id, created_at desc);

create table if not exists public.inventory_reorders (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  product_name text not null default '',
  sku text not null default '',
  quantity numeric(14, 3) not null check (quantity > 0),
  status text not null default 'pending'
    check (status in ('pending', 'ordered', 'received', 'cancelled')),
  source text not null default 'auto'
    check (source in ('auto', 'manual')),
  note text not null default '',
  reorder_date date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, product_id, reorder_date)
);

create index if not exists inventory_reorders_tenant_date_idx
  on public.inventory_reorders (tenant_id, reorder_date desc, status);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.daily_summaries enable row level security;
alter table public.app_notifications enable row level security;
alter table public.inventory_reorders enable row level security;

-- Briefings are readable by every active member of the business. They are
-- written only by the Edge Function (service role) so the narrative and the
-- snapshot always come from one controlled pipeline.
drop policy if exists daily_summaries_select on public.daily_summaries;
create policy daily_summaries_select on public.daily_summaries
  for select to authenticated
  using (public.is_tenant_member(tenant_id));

-- Notifications are private to the targeted profile.
drop policy if exists app_notifications_select on public.app_notifications;
create policy app_notifications_select on public.app_notifications
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists app_notifications_update on public.app_notifications;
create policy app_notifications_update on public.app_notifications
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists app_notifications_delete on public.app_notifications;
create policy app_notifications_delete on public.app_notifications
  for delete to authenticated
  using (user_id = auth.uid());

-- Reorder suggestions follow the same write rules as the product catalogue.
drop policy if exists inventory_reorders_select on public.inventory_reorders;
create policy inventory_reorders_select on public.inventory_reorders
  for select to authenticated
  using (public.is_tenant_member(tenant_id));

drop policy if exists inventory_reorders_insert on public.inventory_reorders;
create policy inventory_reorders_insert on public.inventory_reorders
  for insert to authenticated
  with check (
    public.has_tenant_role(tenant_id, array['admin', 'manager']::text[])
  );

drop policy if exists inventory_reorders_update on public.inventory_reorders;
create policy inventory_reorders_update on public.inventory_reorders
  for update to authenticated
  using (
    public.has_tenant_role(tenant_id, array['admin', 'manager']::text[])
  )
  with check (
    public.has_tenant_role(tenant_id, array['admin', 'manager']::text[])
  );

drop policy if exists inventory_reorders_delete on public.inventory_reorders;
create policy inventory_reorders_delete on public.inventory_reorders
  for delete to authenticated
  using (
    public.has_tenant_role(tenant_id, array['admin', 'manager']::text[])
  );

grant select, insert, update, delete
  on public.daily_summaries, public.app_notifications, public.inventory_reorders
  to authenticated, service_role;

-- Stream new notifications to the owning profile in realtime.
alter table public.app_notifications replica identity full;

do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'app_notifications'
  ) then
    execute 'alter publication supabase_realtime add table public.app_notifications';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- RPC: trigger_daily_reorders
-- ---------------------------------------------------------------------------
-- Creates one idempotent reorder suggestion per low-stock product per day.
-- Returns the rows that were created, plus the date/timezone used.

create or replace function public.trigger_daily_reorders(
  p_tenant_id uuid,
  p_summary_date date default null,
  p_timezone text default 'UTC'
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_timezone text;
  v_date date;
  v_rows jsonb;
  v_created integer;
begin
  if p_tenant_id is null then
    raise exception 'A tenant is required';
  end if;

  if auth.role() <> 'service_role'
     and not public.has_tenant_role(
       p_tenant_id,
       array['admin', 'manager']::text[]
     ) then
    raise exception 'Only admins and managers can trigger reorders';
  end if;

  select coalesce(
    (select zone.name from pg_timezone_names zone where zone.name = p_timezone),
    'UTC'
  ) into v_timezone;

  v_date := coalesce(p_summary_date, (now() at time zone v_timezone)::date);

  with candidates as (
    select
      p.id,
      p.name,
      p.sku,
      greatest(
        ceil((p.low_stock_threshold * 2) - p.stock_qty)::numeric,
        1
      )::numeric(14, 3) as quantity
    from public.products p
    where p.tenant_id = p_tenant_id
      and p.is_active
      and p.stock_qty <= p.low_stock_threshold
  ),
  inserted as (
    insert into public.inventory_reorders (
      tenant_id,
      product_id,
      product_name,
      sku,
      quantity,
      status,
      source,
      note,
      reorder_date,
      created_at,
      updated_at
    )
    select
      p_tenant_id,
      c.id,
      c.name,
      c.sku,
      c.quantity,
      'pending',
      'auto',
      'Auto-reorder: stock is at or below the alert threshold',
      v_date,
      now(),
      now()
    from candidates c
    on conflict (tenant_id, product_id, reorder_date) do nothing
    returning *
  )
  select coalesce(jsonb_agg(to_jsonb(inserted)), '[]'::jsonb), count(*)::integer
    into v_rows, v_created
  from inserted;

  return jsonb_build_object(
    'summary_date', v_date,
    'timezone', v_timezone,
    'created', v_created,
    'reorders', v_rows
  );
end;
$function$;

revoke execute on function public.trigger_daily_reorders(uuid, date, text)
  from public, anon;
grant execute on function public.trigger_daily_reorders(uuid, date, text)
  to authenticated, service_role;

comment on function public.trigger_daily_reorders(uuid, date, text) is
  'Creates one pending reorder suggestion per low-stock product per business day.';

-- ---------------------------------------------------------------------------
-- RPC: build_daily_business_snapshot
-- ---------------------------------------------------------------------------
-- Compiles every number the executive briefing needs. The Edge Function sends
-- this JSON to Gemini, then stores it alongside the narrative.

create or replace function public.build_daily_business_snapshot(
  p_tenant_id uuid,
  p_summary_date date default null,
  p_timezone text default 'UTC'
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_timezone text;
  v_date date;
  v_start timestamptz;
  v_end timestamptz;
  v_prev_start timestamptz;
  v_prev_end timestamptz;

  v_name text;
  v_currency text;
  v_currency_symbol text;

  v_sales_count integer := 0;
  v_revenue numeric := 0;
  v_paid numeric := 0;
  v_new_credit numeric := 0;
  v_cost_of_goods numeric := 0;

  v_expense_count integer := 0;
  v_expenses numeric := 0;
  v_expense_categories jsonb := '[]'::jsonb;

  v_ledger_collected numeric := 0;
  v_receivables numeric := 0;
  v_payables numeric := 0;

  v_top_products jsonb := '[]'::jsonb;
  v_low_stock jsonb := '[]'::jsonb;
  v_reorders jsonb := '[]'::jsonb;

  v_prev_sales_count integer := 0;
  v_prev_revenue numeric := 0;
  v_prev_expenses numeric := 0;
  v_prev_cost_of_goods numeric := 0;

  v_metrics jsonb;
begin
  if p_tenant_id is null then
    raise exception 'A tenant is required';
  end if;

  if auth.role() <> 'service_role'
     and not public.has_tenant_role(
       p_tenant_id,
       array['admin', 'manager']::text[]
     ) then
    raise exception 'Only admins and managers can build a briefing';
  end if;

  select t.name, t.currency, t.currency_symbol
    into v_name, v_currency, v_currency_symbol
  from public.tenants t
  where t.id = p_tenant_id;

  if not found then
    raise exception 'Business not found';
  end if;

  select coalesce(
    (select zone.name from pg_timezone_names zone where zone.name = p_timezone),
    'UTC'
  ) into v_timezone;

  v_date := coalesce(p_summary_date, (now() at time zone v_timezone)::date);
  v_start := (v_date::timestamp) at time zone v_timezone;
  v_end := ((v_date + 1)::timestamp) at time zone v_timezone;
  v_prev_start := ((v_date - 1)::timestamp) at time zone v_timezone;
  v_prev_end := v_start;

  -- Sales for the business day ------------------------------------------------
  select
    count(*)::integer,
    coalesce(sum(s.total), 0),
    coalesce(sum(s.paid_amount), 0),
    coalesce(sum(s.due_amount), 0)
  into v_sales_count, v_revenue, v_paid, v_new_credit
  from public.sales s
  where s.tenant_id = p_tenant_id
    and s.status = 'completed'
    and s.created_at >= v_start
    and s.created_at < v_end;

  select coalesce(sum(si.cost_price * si.quantity), 0)
    into v_cost_of_goods
  from public.sale_items si
  join public.sales s on s.id = si.sale_id
  where s.tenant_id = p_tenant_id
    and s.status = 'completed'
    and s.created_at >= v_start
    and s.created_at < v_end;

  -- Expenses for the calendar day ---------------------------------------------
  select count(*)::integer, coalesce(sum(e.amount), 0)
    into v_expense_count, v_expenses
  from public.expenses e
  where e.tenant_id = p_tenant_id
    and e.expense_date >= v_date
    and e.expense_date < (v_date + 1);

  select coalesce(
    jsonb_agg(
      jsonb_build_object('category', c.category, 'amount', c.amount)
      order by c.amount desc
    ),
    '[]'::jsonb
  )
  into v_expense_categories
  from (
    select e.category, sum(e.amount) as amount
    from public.expenses e
    where e.tenant_id = p_tenant_id
      and e.expense_date >= v_date
      and e.expense_date < (v_date + 1)
    group by e.category
    order by sum(e.amount) desc
    limit 5
  ) c;

  -- Cash received against earlier credit sales --------------------------------
  select coalesce(sum(le.amount), 0)
    into v_ledger_collected
  from public.ledger_entries le
  where le.tenant_id = p_tenant_id
    and le.entry_type = 'payment'
    and le.created_at >= v_start
    and le.created_at < v_end;

  -- Outstanding balances -------------------------------------------------------
  select
    coalesce(sum(a.balance) filter (where a.account_type = 'customer'), 0),
    coalesce(sum(a.balance) filter (where a.account_type = 'supplier'), 0)
  into v_receivables, v_payables
  from public.ledger_accounts a
  where a.tenant_id = p_tenant_id;

  -- Best sellers ----------------------------------------------------------------
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'name', p.product_name,
        'quantity', p.quantity,
        'revenue', p.revenue
      )
      order by p.revenue desc
    ),
    '[]'::jsonb
  )
  into v_top_products
  from (
    select
      si.product_name,
      sum(si.quantity) as quantity,
      sum(si.line_total) as revenue
    from public.sale_items si
    join public.sales s on s.id = si.sale_id
    where s.tenant_id = p_tenant_id
      and s.status = 'completed'
      and s.created_at >= v_start
      and s.created_at < v_end
    group by si.product_name
    order by sum(si.line_total) desc
    limit 5
  ) p;

  -- Low stock and reorders raised today ----------------------------------------
  select coalesce(
    jsonb_agg(to_jsonb(p) order by p.stock_qty asc),
    '[]'::jsonb
  )
  into v_low_stock
  from (
    select
      pr.id,
      pr.name,
      pr.sku,
      pr.unit,
      pr.stock_qty,
      pr.low_stock_threshold
    from public.products pr
    where pr.tenant_id = p_tenant_id
      and pr.is_active
      and pr.stock_qty <= pr.low_stock_threshold
    order by pr.stock_qty asc
    limit 20
  ) p;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', r.id,
        'product_id', r.product_id,
        'product_name', r.product_name,
        'sku', r.sku,
        'quantity', r.quantity,
        'status', r.status,
        'source', r.source
      )
      order by r.created_at asc
    ),
    '[]'::jsonb
  )
  into v_reorders
  from public.inventory_reorders r
  where r.tenant_id = p_tenant_id
    and r.reorder_date = v_date;

  -- Previous day, for context ---------------------------------------------------
  select
    count(*)::integer,
    coalesce(sum(s.total), 0)
  into v_prev_sales_count, v_prev_revenue
  from public.sales s
  where s.tenant_id = p_tenant_id
    and s.status = 'completed'
    and s.created_at >= v_prev_start
    and s.created_at < v_prev_end;

  select coalesce(sum(si.cost_price * si.quantity), 0)
    into v_prev_cost_of_goods
  from public.sale_items si
  join public.sales s on s.id = si.sale_id
  where s.tenant_id = p_tenant_id
    and s.status = 'completed'
    and s.created_at >= v_prev_start
    and s.created_at < v_prev_end;

  select coalesce(sum(e.amount), 0)
    into v_prev_expenses
  from public.expenses e
  where e.tenant_id = p_tenant_id
    and e.expense_date >= (v_date - 1)
    and e.expense_date < v_date;

  v_metrics := jsonb_build_object(
    'summary_date', v_date,
    'timezone', v_timezone,
    'business_name', v_name,
    'currency', v_currency,
    'currency_symbol', v_currency_symbol,
    'window_start', v_start,
    'window_end', v_end,
    'sales', jsonb_build_object(
      'count', v_sales_count,
      'revenue', v_revenue,
      'cost_of_goods', v_cost_of_goods,
      'gross_profit', v_revenue - v_cost_of_goods
    ),
    'expenses', jsonb_build_object(
      'count', v_expense_count,
      'total', v_expenses,
      'by_category', v_expense_categories
    ),
    'net_profit', v_revenue - v_cost_of_goods - v_expenses,
    'cash_collected', v_paid + v_ledger_collected,
    'sales_cash_collected', v_paid,
    'ledger_collected', v_ledger_collected,
    'new_credit', v_new_credit,
    'receivables', v_receivables,
    'payables', v_payables,
    'top_products', v_top_products,
    'low_stock', v_low_stock,
    'reorders', v_reorders,
    'reorder_count', jsonb_array_length(v_reorders),
    'previous', jsonb_build_object(
      'sales_count', v_prev_sales_count,
      'revenue', v_prev_revenue,
      'expenses', v_prev_expenses,
      'net_profit', v_prev_revenue - v_prev_cost_of_goods - v_prev_expenses
    )
  );

  return v_metrics;
end;
$function$;

revoke execute on function public.build_daily_business_snapshot(uuid, date, text)
  from public, anon;
grant execute on function public.build_daily_business_snapshot(uuid, date, text)
  to authenticated, service_role;

comment on function public.build_daily_business_snapshot(uuid, date, text) is
  'Builds the structured daily business snapshot used by the AI executive briefing.';

-- ---------------------------------------------------------------------------
-- RPC: list_due_daily_summaries
-- ---------------------------------------------------------------------------
-- Called by the scheduled Edge Function. A manual briefing does not suppress
-- the scheduled evening briefing for the same day.

create or replace function public.list_due_daily_summaries(
  p_limit integer default 50
)
returns table (
  tenant_id uuid,
  tenant_name text,
  summary_date date,
  briefing_timezone text,
  scheduled_time time
)
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
begin
  if auth.role() <> 'service_role' then
    raise exception 'Only the scheduler can list due briefings';
  end if;

  return query
  with zones as (
    select
      t.id,
      t.name,
      t.daily_briefing_time,
      coalesce(
        (select zone.name from pg_timezone_names zone
         where zone.name = t.daily_briefing_timezone),
        'UTC'
      ) as zone
    from public.tenants t
    where t.daily_briefing_enabled
  ),
  local as (
    select
      z.id,
      z.name,
      z.daily_briefing_time,
      z.zone,
      (now() at time zone z.zone)::date as local_date,
      (now() at time zone z.zone)::time as local_time
    from zones z
  )
  select
    l.id as tenant_id,
    l.name as tenant_name,
    l.local_date as summary_date,
    l.zone as briefing_timezone,
    l.daily_briefing_time as scheduled_time
  from local l
  where l.local_time >= l.daily_briefing_time
    and not exists (
      select 1
      from public.daily_summaries d
      where d.tenant_id = l.id
        and d.summary_date = l.local_date
        and not d.is_manual
    )
  order by (l.local_time - l.daily_briefing_time) desc
  limit greatest(coalesce(p_limit, 50), 1);
end;
$function$;

revoke all on function public.list_due_daily_summaries(integer)
  from public, anon, authenticated;
grant execute on function public.list_due_daily_summaries(integer)
  to service_role;

comment on function public.list_due_daily_summaries(integer) is
  'Returns businesses whose local briefing time has passed and still need a scheduled summary today.';
