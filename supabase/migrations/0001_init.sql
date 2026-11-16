-- Afraz Flow — production schema, Row Level Security and transactional RPCs.
--
-- Tenancy model
-- -------------
-- Every business row carries `tenant_id`. Access is granted only through an
-- active row in `tenant_members` for `auth.uid()`. The helper functions below
-- are SECURITY DEFINER so policies can inspect memberships without recursively
-- evaluating the RLS policy on `tenant_members` itself.
--
-- Apply with the Supabase CLI:
--   supabase db push
-- or paste this file into the SQL editor of a fresh project.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  business_type text not null default 'Other',
  currency text not null default 'PKR',
  currency_symbol text not null default 'Rs',
  tax_rate numeric(6, 2) not null default 0 check (tax_rate >= 0 and tax_rate <= 100),
  low_stock_threshold integer not null default 5 check (low_stock_threshold >= 0),
  phone text,
  email text,
  address text,
  logo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  full_name text not null default 'Team member',
  phone text,
  avatar_url text,
  created_at timestamptz not null default now()
);

create index if not exists profiles_email_idx on public.profiles (lower(email));

create table if not exists public.tenant_members (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'cashier' check (role in ('admin', 'manager', 'cashier')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (tenant_id, user_id)
);

create index if not exists tenant_members_tenant_idx
  on public.tenant_members (tenant_id, is_active);
create index if not exists tenant_members_user_idx
  on public.tenant_members (user_id, is_active);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  sku text not null,
  barcode text,
  category text not null default 'Uncategorised',
  unit text not null default 'pcs',
  cost_price numeric(14, 2) not null default 0 check (cost_price >= 0),
  sale_price numeric(14, 2) not null default 0 check (sale_price >= 0),
  stock_qty numeric(14, 3) not null default 0 check (stock_qty >= 0),
  low_stock_threshold integer not null default 5 check (low_stock_threshold >= 0),
  is_active boolean not null default true,
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, sku)
);

create unique index if not exists products_tenant_barcode_idx
  on public.products (tenant_id, barcode)
  where barcode is not null;

create index if not exists products_tenant_active_idx
  on public.products (tenant_id, is_active, name);

create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  product_name text not null default '',
  movement_type text not null check (movement_type in ('in', 'out', 'adjustment')),
  quantity numeric(14, 3) not null check (quantity >= 0),
  note text not null default '',
  reference text,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists stock_movements_tenant_created_idx
  on public.stock_movements (tenant_id, created_at desc);
create index if not exists stock_movements_product_idx
  on public.stock_movements (product_id, created_at desc);

create table if not exists public.ledger_accounts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  account_type text not null default 'customer' check (account_type in ('customer', 'supplier')),
  opening_balance numeric(14, 2) not null default 0,
  balance numeric(14, 2) not null default 0,
  phone text,
  email text,
  address text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ledger_accounts_tenant_type_idx
  on public.ledger_accounts (tenant_id, account_type, name);

create table if not exists public.ledger_entries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  account_id uuid not null references public.ledger_accounts (id) on delete cascade,
  entry_type text not null check (entry_type in ('charge', 'payment')),
  amount numeric(14, 2) not null check (amount > 0),
  entry_date date not null default current_date,
  description text not null default '',
  reference text,
  created_at timestamptz not null default now()
);

create index if not exists ledger_entries_tenant_created_idx
  on public.ledger_entries (tenant_id, created_at desc);
create index if not exists ledger_entries_account_idx
  on public.ledger_entries (account_id, created_at desc);

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  invoice_no text not null,
  account_id uuid references public.ledger_accounts (id) on delete set null,
  customer_name text not null default 'Walk-in customer',
  subtotal numeric(14, 2) not null default 0 check (subtotal >= 0),
  discount numeric(14, 2) not null default 0 check (discount >= 0),
  tax numeric(14, 2) not null default 0 check (tax >= 0),
  total numeric(14, 2) not null default 0 check (total >= 0),
  paid_amount numeric(14, 2) not null default 0 check (paid_amount >= 0),
  due_amount numeric(14, 2) not null default 0 check (due_amount >= 0),
  payment_method text not null default 'cash'
    check (payment_method in ('cash', 'card', 'bank', 'credit')),
  status text not null default 'completed'
    check (status in ('completed', 'refunded', 'voided')),
  note text,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, invoice_no)
);

create index if not exists sales_tenant_created_idx
  on public.sales (tenant_id, created_at desc);
create index if not exists sales_account_idx on public.sales (account_id);

create table if not exists public.sale_items (
  -- Sale item ids are derived (`<sale_id>_<line>`), so this is text rather
  -- than uuid. Sale ids themselves remain uuid.
  id text primary key,
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  sale_id uuid not null references public.sales (id) on delete cascade,
  product_id uuid references public.products (id) on delete set null,
  product_name text not null default '',
  sku text not null default '',
  quantity numeric(14, 3) not null check (quantity > 0),
  unit_price numeric(14, 2) not null default 0 check (unit_price >= 0),
  cost_price numeric(14, 2) not null default 0 check (cost_price >= 0),
  line_total numeric(14, 2) not null default 0 check (line_total >= 0),
  created_at timestamptz not null default now()
);

create index if not exists sale_items_tenant_idx on public.sale_items (tenant_id);
create index if not exists sale_items_sale_idx on public.sale_items (sale_id);
create index if not exists sale_items_product_idx on public.sale_items (product_id);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  category text not null default 'Other',
  description text not null default '',
  amount numeric(14, 2) not null check (amount > 0),
  payment_method text not null default 'cash',
  expense_date date not null default current_date,
  reference text,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists expenses_tenant_date_idx
  on public.expenses (tenant_id, expense_date desc);

create table if not exists public.courier_orders (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  order_no text not null,
  sale_id uuid references public.sales (id) on delete set null,
  customer_name text not null default 'Customer',
  customer_phone text not null default '',
  address text not null default '',
  city text not null default '',
  courier_partner text not null default 'TCS',
  tracking_number text,
  status text not null default 'pending'
    check (status in ('pending', 'shipped', 'delivered', 'returned', 'cancelled')),
  cod_amount numeric(14, 2) not null default 0 check (cod_amount >= 0),
  cod_collected boolean not null default false,
  shipping_fee numeric(14, 2) not null default 0 check (shipping_fee >= 0),
  notes text,
  dispatched_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, order_no)
);

create index if not exists courier_orders_tenant_created_idx
  on public.courier_orders (tenant_id, created_at desc);
create index if not exists courier_orders_tenant_status_idx
  on public.courier_orders (tenant_id, status);

create table if not exists public.courier_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  courier_order_id uuid not null references public.courier_orders (id) on delete cascade,
  status text not null
    check (status in ('pending', 'shipped', 'delivered', 'returned', 'cancelled')),
  note text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists courier_events_order_idx
  on public.courier_events (courier_order_id, created_at);
create index if not exists courier_events_tenant_idx
  on public.courier_events (tenant_id);

-- ---------------------------------------------------------------------------
-- Membership helpers (SECURITY DEFINER avoids recursive RLS evaluation)
-- ---------------------------------------------------------------------------

create or replace function public.is_tenant_member(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.tenant_members m
    where m.tenant_id = p_tenant_id
      and m.user_id = auth.uid()
      and m.is_active
  );
$$;

create or replace function public.has_tenant_role(p_tenant_id uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.tenant_members m
    where m.tenant_id = p_tenant_id
      and m.user_id = auth.uid()
      and m.is_active
      and m.role = any (p_roles)
  );
$$;

create or replace function public.shares_tenant_with(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.tenant_members me
    join public.tenant_members them on them.tenant_id = me.tenant_id
    where me.user_id = auth.uid()
      and me.is_active
      and them.user_id = p_user_id
  );
$$;

revoke execute on function public.is_tenant_member(uuid) from public, anon;
revoke execute on function public.has_tenant_role(uuid, text[]) from public, anon;
revoke execute on function public.shares_tenant_with(uuid) from public, anon;
grant execute on function public.is_tenant_member(uuid) to authenticated, service_role;
grant execute on function public.has_tenant_role(uuid, text[]) to authenticated, service_role;
grant execute on function public.shares_tenant_with(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- New auth user -> public profile
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, email, full_name, phone, avatar_url)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
      split_part(coalesce(new.email, 'member'), '@', 1)
    ),
    nullif(trim(new.raw_user_meta_data ->> 'phone'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'avatar_url'), '')
  )
  on conflict (id) do update
    set email = excluded.email,
        full_name = excluded.full_name,
        phone = coalesce(excluded.phone, profiles.phone),
        avatar_url = coalesce(excluded.avatar_url, profiles.avatar_url);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.tenants enable row level security;
alter table public.profiles enable row level security;
alter table public.tenant_members enable row level security;
alter table public.products enable row level security;
alter table public.stock_movements enable row level security;
alter table public.ledger_accounts enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.expenses enable row level security;
alter table public.courier_orders enable row level security;
alter table public.courier_events enable row level security;

-- Tenants ------------------------------------------------------------------
drop policy if exists tenants_select on public.tenants;
create policy tenants_select on public.tenants
  for select to authenticated
  using (public.is_tenant_member(id));

drop policy if exists tenants_update on public.tenants;
create policy tenants_update on public.tenants
  for update to authenticated
  using (public.has_tenant_role(id, array['admin']::text[]))
  with check (public.has_tenant_role(id, array['admin']::text[]));

-- Profiles -----------------------------------------------------------------
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.shares_tenant_with(id));

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Memberships --------------------------------------------------------------
drop policy if exists tenant_members_select on public.tenant_members;
create policy tenant_members_select on public.tenant_members
  for select to authenticated
  using (user_id = auth.uid() or public.is_tenant_member(tenant_id));

drop policy if exists tenant_members_insert on public.tenant_members;
create policy tenant_members_insert on public.tenant_members
  for insert to authenticated
  with check (public.has_tenant_role(tenant_id, array['admin']::text[]));

drop policy if exists tenant_members_update on public.tenant_members;
create policy tenant_members_update on public.tenant_members
  for update to authenticated
  using (public.has_tenant_role(tenant_id, array['admin']::text[]))
  with check (public.has_tenant_role(tenant_id, array['admin']::text[]));

drop policy if exists tenant_members_delete on public.tenant_members;
create policy tenant_members_delete on public.tenant_members
  for delete to authenticated
  using (public.has_tenant_role(tenant_id, array['admin']::text[]));

-- Products -----------------------------------------------------------------
drop policy if exists products_select on public.products;
create policy products_select on public.products
  for select to authenticated
  using (public.is_tenant_member(tenant_id));

drop policy if exists products_insert on public.products;
create policy products_insert on public.products
  for insert to authenticated
  with check (public.has_tenant_role(tenant_id, array['admin', 'manager']::text[]));

drop policy if exists products_update on public.products;
create policy products_update on public.products
  for update to authenticated
  using (public.has_tenant_role(tenant_id, array['admin', 'manager']::text[]))
  with check (public.has_tenant_role(tenant_id, array['admin', 'manager']::text[]));

drop policy if exists products_delete on public.products;
create policy products_delete on public.products
  for delete to authenticated
  using (public.has_tenant_role(tenant_id, array['admin', 'manager']::text[]));

-- Stock movements ----------------------------------------------------------
drop policy if exists stock_movements_select on public.stock_movements;
create policy stock_movements_select on public.stock_movements
  for select to authenticated
  using (public.is_tenant_member(tenant_id));

drop policy if exists stock_movements_insert on public.stock_movements;
create policy stock_movements_insert on public.stock_movements
  for insert to authenticated
  with check (public.has_tenant_role(tenant_id, array['admin', 'manager']::text[]));

-- Ledger accounts ----------------------------------------------------------
drop policy if exists ledger_accounts_select on public.ledger_accounts;
create policy ledger_accounts_select on public.ledger_accounts
  for select to authenticated
  using (public.is_tenant_member(tenant_id));

drop policy if exists ledger_accounts_insert on public.ledger_accounts;
create policy ledger_accounts_insert on public.ledger_accounts
  for insert to authenticated
  with check (public.has_tenant_role(tenant_id, array['admin', 'manager']::text[]));

drop policy if exists ledger_accounts_update on public.ledger_accounts;
create policy ledger_accounts_update on public.ledger_accounts
  for update to authenticated
  using (public.has_tenant_role(tenant_id, array['admin', 'manager']::text[]))
  with check (public.has_tenant_role(tenant_id, array['admin', 'manager']::text[]));

drop policy if exists ledger_accounts_delete on public.ledger_accounts;
create policy ledger_accounts_delete on public.ledger_accounts
  for delete to authenticated
  using (public.has_tenant_role(tenant_id, array['admin', 'manager']::text[]));

-- Ledger entries -----------------------------------------------------------
drop policy if exists ledger_entries_select on public.ledger_entries;
create policy ledger_entries_select on public.ledger_entries
  for select to authenticated
  using (public.is_tenant_member(tenant_id));

drop policy if exists ledger_entries_insert on public.ledger_entries;
create policy ledger_entries_insert on public.ledger_entries
  for insert to authenticated
  with check (public.has_tenant_role(tenant_id, array['admin', 'manager']::text[]));

drop policy if exists ledger_entries_delete on public.ledger_entries;
create policy ledger_entries_delete on public.ledger_entries
  for delete to authenticated
  using (public.has_tenant_role(tenant_id, array['admin', 'manager']::text[]));

-- Sales --------------------------------------------------------------------
drop policy if exists sales_select on public.sales;
create policy sales_select on public.sales
  for select to authenticated
  using (public.is_tenant_member(tenant_id));

drop policy if exists sales_insert on public.sales;
create policy sales_insert on public.sales
  for insert to authenticated
  with check (public.is_tenant_member(tenant_id));

drop policy if exists sales_update on public.sales;
create policy sales_update on public.sales
  for update to authenticated
  using (public.has_tenant_role(tenant_id, array['admin', 'manager']::text[]))
  with check (public.has_tenant_role(tenant_id, array['admin', 'manager']::text[]));

drop policy if exists sales_delete on public.sales;
create policy sales_delete on public.sales
  for delete to authenticated
  using (public.has_tenant_role(tenant_id, array['admin']::text[]));

-- Sale items ---------------------------------------------------------------
drop policy if exists sale_items_select on public.sale_items;
create policy sale_items_select on public.sale_items
  for select to authenticated
  using (public.is_tenant_member(tenant_id));

drop policy if exists sale_items_insert on public.sale_items;
create policy sale_items_insert on public.sale_items
  for insert to authenticated
  with check (public.is_tenant_member(tenant_id));

drop policy if exists sale_items_delete on public.sale_items;
create policy sale_items_delete on public.sale_items
  for delete to authenticated
  using (public.has_tenant_role(tenant_id, array['admin', 'manager']::text[]));

-- Expenses -----------------------------------------------------------------
drop policy if exists expenses_select on public.expenses;
create policy expenses_select on public.expenses
  for select to authenticated
  using (public.is_tenant_member(tenant_id));

drop policy if exists expenses_insert on public.expenses;
create policy expenses_insert on public.expenses
  for insert to authenticated
  with check (public.has_tenant_role(tenant_id, array['admin', 'manager']::text[]));

drop policy if exists expenses_update on public.expenses;
create policy expenses_update on public.expenses
  for update to authenticated
  using (public.has_tenant_role(tenant_id, array['admin', 'manager']::text[]))
  with check (public.has_tenant_role(tenant_id, array['admin', 'manager']::text[]));

drop policy if exists expenses_delete on public.expenses;
create policy expenses_delete on public.expenses
  for delete to authenticated
  using (public.has_tenant_role(tenant_id, array['admin', 'manager']::text[]));

-- Courier ------------------------------------------------------------------
drop policy if exists courier_orders_select on public.courier_orders;
create policy courier_orders_select on public.courier_orders
  for select to authenticated
  using (public.is_tenant_member(tenant_id));

drop policy if exists courier_orders_insert on public.courier_orders;
create policy courier_orders_insert on public.courier_orders
  for insert to authenticated
  with check (public.is_tenant_member(tenant_id));

drop policy if exists courier_orders_update on public.courier_orders;
create policy courier_orders_update on public.courier_orders
  for update to authenticated
  using (public.is_tenant_member(tenant_id))
  with check (public.is_tenant_member(tenant_id));

drop policy if exists courier_orders_delete on public.courier_orders;
create policy courier_orders_delete on public.courier_orders
  for delete to authenticated
  using (public.is_tenant_member(tenant_id));

drop policy if exists courier_events_select on public.courier_events;
create policy courier_events_select on public.courier_events
  for select to authenticated
  using (public.is_tenant_member(tenant_id));

drop policy if exists courier_events_insert on public.courier_events;
create policy courier_events_insert on public.courier_events
  for insert to authenticated
  with check (public.is_tenant_member(tenant_id));

drop policy if exists courier_events_delete on public.courier_events;
create policy courier_events_delete on public.courier_events
  for delete to authenticated
  using (public.is_tenant_member(tenant_id));

-- Table privileges (RLS still applies) ------------------------------------
grant usage on schema public to authenticated, service_role;
grant select, insert, update, delete on all tables in schema public to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: create_organization
-- ---------------------------------------------------------------------------

create or replace function public.create_organization(
  p_name text,
  p_business_type text,
  p_currency text,
  p_currency_symbol text,
  p_tax_rate numeric,
  p_low_stock_threshold integer,
  p_phone text,
  p_full_name text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_existing_tenant uuid;
  v_tenant_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;
  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'Business name is required';
  end if;

  -- Idempotent: repeated calls (for example after email confirmation) reuse
  -- the organization the user already belongs to.
  select m.tenant_id into v_existing_tenant
  from public.tenant_members m
  where m.user_id = v_user_id and m.is_active
  order by m.created_at
  limit 1;

  if v_existing_tenant is not null then
    return v_existing_tenant;
  end if;

  select u.email into v_email from auth.users u where u.id = v_user_id;

  insert into public.profiles (id, email, full_name, phone)
  values (
    v_user_id,
    coalesce(v_email, ''),
    coalesce(nullif(trim(p_full_name), ''), split_part(coalesce(v_email, 'owner'), '@', 1)),
    nullif(trim(p_phone), '')
  )
  on conflict (id) do update
    set email = excluded.email,
        full_name = case
          when length(trim(excluded.full_name)) > 0 then excluded.full_name
          else profiles.full_name
        end,
        phone = coalesce(excluded.phone, profiles.phone);

  insert into public.tenants (
    name, business_type, currency, currency_symbol, tax_rate,
    low_stock_threshold, phone, email
  )
  values (
    trim(p_name),
    coalesce(nullif(trim(p_business_type), ''), 'Other'),
    coalesce(nullif(trim(p_currency), ''), 'PKR'),
    coalesce(nullif(trim(p_currency_symbol), ''), 'Rs'),
    coalesce(p_tax_rate, 0),
    coalesce(p_low_stock_threshold, 5),
    nullif(trim(p_phone), ''),
    v_email
  )
  returning id into v_tenant_id;

  insert into public.tenant_members (tenant_id, user_id, role, is_active)
  values (v_tenant_id, v_user_id, 'admin', true);

  return v_tenant_id;
end;
$$;

revoke execute on function public.create_organization(
  text, text, text, text, numeric, integer, text, text
) from public, anon;
grant execute on function public.create_organization(
  text, text, text, text, numeric, integer, text, text
) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- RPC: checkout_sale
-- ---------------------------------------------------------------------------
-- Creates the sale, line items, stock deductions, stock movements and the
-- ledger charge in one transaction. Mirrors SaleRepository.checkout().

create or replace function public.checkout_sale(
  p_tenant_id uuid,
  p_sale_id uuid,
  p_invoice_no text,
  p_account_id uuid,
  p_customer_name text,
  p_subtotal numeric,
  p_discount numeric,
  p_tax numeric,
  p_total numeric,
  p_paid_amount numeric,
  p_payment_method text,
  p_note text,
  p_items jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_item jsonb;
  v_product_id uuid;
  v_quantity numeric;
  v_product_name text;
  v_stock numeric;
  v_due numeric;
  v_total numeric := coalesce(p_total, 0);
  v_paid numeric := coalesce(p_paid_amount, 0);
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;
  if not public.is_tenant_member(p_tenant_id) then
    raise exception 'You are not a member of this organization';
  end if;
  if p_items is null
     or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'A sale must contain at least one item';
  end if;
  if coalesce(p_payment_method, '') not in ('cash', 'card', 'bank', 'credit') then
    raise exception 'Unsupported payment method: %', p_payment_method;
  end if;
  if v_paid < 0 or v_total < 0 then
    raise exception 'Sale amounts cannot be negative';
  end if;
  if abs(
       coalesce(p_subtotal, 0)
       - coalesce(p_discount, 0)
       + coalesce(p_tax, 0)
       - v_total
     ) > 0.02 then
    raise exception 'Sale totals are inconsistent';
  end if;
  if v_paid > v_total + 0.009 then
    raise exception 'Paid amount cannot exceed the sale total';
  end if;

  v_due := greatest(v_total - v_paid, 0);
  if v_due > 0.009 and p_account_id is null then
    raise exception 'An account is required for an outstanding balance';
  end if;

  insert into public.sales (
    id, tenant_id, invoice_no, account_id, customer_name, subtotal,
    discount, tax, total, paid_amount, due_amount, payment_method, status,
    note, created_by, created_at, updated_at
  )
  values (
    p_sale_id,
    p_tenant_id,
    p_invoice_no,
    p_account_id,
    coalesce(nullif(trim(p_customer_name), ''), 'Walk-in customer'),
    coalesce(p_subtotal, 0),
    coalesce(p_discount, 0),
    coalesce(p_tax, 0),
    v_total,
    v_paid,
    v_due,
    p_payment_method,
    'completed',
    nullif(trim(p_note), ''),
    v_user_id,
    now(),
    now()
  );

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_product_id := (v_item ->> 'product_id')::uuid;
    v_quantity := coalesce((v_item ->> 'quantity')::numeric, 0);

    if v_quantity <= 0 then
      raise exception 'Item quantities must be greater than zero';
    end if;
    if v_product_id is null then
      raise exception 'Every sale item needs a product';
    end if;

    select p.name, p.stock_qty
      into v_product_name, v_stock
    from public.products p
    where p.id = v_product_id and p.tenant_id = p_tenant_id
    for update;

    if not found then
      raise exception 'A product in this sale no longer exists';
    end if;
    if v_stock < v_quantity then
      raise exception 'Not enough stock for %', v_product_name;
    end if;

    insert into public.sale_items (
      id, tenant_id, sale_id, product_id, product_name, sku, quantity,
      unit_price, cost_price, line_total, created_at
    )
    values (
      coalesce(v_item ->> 'id', p_sale_id::text || '_' || (v_item ->> 'product_id')),
      p_tenant_id,
      p_sale_id,
      v_product_id,
      coalesce(nullif(v_item ->> 'product_name', ''), v_product_name),
      coalesce(v_item ->> 'sku', ''),
      v_quantity,
      coalesce((v_item ->> 'unit_price')::numeric, 0),
      coalesce((v_item ->> 'cost_price')::numeric, 0),
      coalesce((v_item ->> 'line_total')::numeric, 0),
      now()
    );

    update public.products
      set stock_qty = stock_qty - v_quantity,
          updated_at = now()
      where id = v_product_id and tenant_id = p_tenant_id;

    insert into public.stock_movements (
      tenant_id, product_id, product_name, movement_type, quantity,
      note, reference, created_by, created_at
    )
    values (
      p_tenant_id,
      v_product_id,
      v_product_name,
      'out',
      v_quantity,
      'Sold on ' || p_invoice_no,
      p_invoice_no,
      v_user_id,
      now()
    );
  end loop;

  if v_due > 0.009 and p_account_id is not null then
    update public.ledger_accounts
      set balance = balance + v_due,
          updated_at = now()
      where id = p_account_id and tenant_id = p_tenant_id;

    if not found then
      raise exception 'Customer account could not be found';
    end if;

    insert into public.ledger_entries (
      tenant_id, account_id, entry_type, amount, entry_date,
      description, reference, created_at
    )
    values (
      p_tenant_id,
      p_account_id,
      'charge',
      v_due,
      current_date,
      'Credit sale — ' || p_invoice_no,
      p_invoice_no,
      now()
    );
  end if;
end;
$$;

revoke execute on function public.checkout_sale(
  uuid, uuid, text, uuid, text, numeric, numeric, numeric, numeric, numeric,
  text, text, jsonb
) from public, anon;
grant execute on function public.checkout_sale(
  uuid, uuid, text, uuid, text, numeric, numeric, numeric, numeric, numeric,
  text, text, jsonb
) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- RPC: adjust_stock
-- ---------------------------------------------------------------------------
-- `p_type` is 'in' | 'out' | 'adjustment'. For an adjustment, `p_quantity`
-- is the new absolute stock level.

create or replace function public.adjust_stock(
  p_tenant_id uuid,
  p_product_id uuid,
  p_quantity numeric,
  p_type text,
  p_note text,
  p_reference text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_name text;
  v_stock numeric;
  v_new_stock numeric;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;
  if not public.has_tenant_role(p_tenant_id, array['admin', 'manager']::text[]) then
    raise exception 'Only admins and managers can adjust stock';
  end if;
  if p_type is null or p_type not in ('in', 'out', 'adjustment') then
    raise exception 'Unsupported stock movement type: %', p_type;
  end if;
  if p_quantity is null or p_quantity < 0 then
    raise exception 'Quantity cannot be negative';
  end if;

  select p.name, p.stock_qty
    into v_name, v_stock
  from public.products p
  where p.id = p_product_id and p.tenant_id = p_tenant_id
  for update;

  if not found then
    raise exception 'Product not found';
  end if;

  v_new_stock := case p_type
    when 'in' then v_stock + p_quantity
    when 'out' then v_stock - p_quantity
    else p_quantity
  end;

  if v_new_stock < 0 then
    raise exception 'This would reduce stock below zero';
  end if;

  update public.products
    set stock_qty = v_new_stock,
        updated_at = now()
    where id = p_product_id and tenant_id = p_tenant_id;

  insert into public.stock_movements (
    tenant_id, product_id, product_name, movement_type, quantity,
    note, reference, created_by, created_at
  )
  values (
    p_tenant_id,
    p_product_id,
    v_name,
    p_type,
    p_quantity,
    coalesce(p_note, ''),
    nullif(trim(p_reference), ''),
    v_user_id,
    now()
  );
end;
$$;

revoke execute on function public.adjust_stock(
  uuid, uuid, numeric, text, text, text
) from public, anon;
grant execute on function public.adjust_stock(
  uuid, uuid, numeric, text, text, text
) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- RPC: record_ledger_entry
-- ---------------------------------------------------------------------------

create or replace function public.record_ledger_entry(
  p_tenant_id uuid,
  p_account_id uuid,
  p_entry_type text,
  p_amount numeric,
  p_description text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_balance numeric;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if not public.has_tenant_role(p_tenant_id, array['admin', 'manager']::text[]) then
    raise exception 'Only admins and managers can update accounts';
  end if;
  if p_entry_type is null or p_entry_type not in ('charge', 'payment') then
    raise exception 'Unsupported ledger entry type: %', p_entry_type;
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Amount must be greater than zero';
  end if;

  select a.balance into v_balance
  from public.ledger_accounts a
  where a.id = p_account_id and a.tenant_id = p_tenant_id
  for update;

  if not found then
    raise exception 'Account not found';
  end if;
  if p_entry_type = 'payment' and p_amount > v_balance then
    raise exception 'Payment exceeds the outstanding balance of %', v_balance;
  end if;

  update public.ledger_accounts
    set balance = case
          when p_entry_type = 'charge' then balance + p_amount
          else balance - p_amount
        end,
        updated_at = now()
    where id = p_account_id and tenant_id = p_tenant_id;

  insert into public.ledger_entries (
    tenant_id, account_id, entry_type, amount, entry_date,
    description, created_at
  )
  values (
    p_tenant_id,
    p_account_id,
    p_entry_type,
    p_amount,
    current_date,
    coalesce(nullif(trim(p_description), ''), 'Account adjustment'),
    now()
  );
end;
$$;

revoke execute on function public.record_ledger_entry(
  uuid, uuid, text, numeric, text
) from public, anon;
grant execute on function public.record_ledger_entry(
  uuid, uuid, text, numeric, text
) to authenticated, service_role;
