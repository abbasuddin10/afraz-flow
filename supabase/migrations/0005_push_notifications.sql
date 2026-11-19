-- Push notifications (Firebase Cloud Messaging) + dedicated low stock alerts.
--
-- Flow
-- ----
-- 1. The mobile app registers its FCM device token in `fcm_tokens`
--    (PushNotificationService in the Dart app).
-- 2. Whenever a row is INSERTed into `app_notifications` — the Daily AI
--    Briefing pipeline (Edge Function or the local generate) OR the new
--    `low_stock` alerts below — the `app_notifications_push` trigger posts
--    the row to the `notify-push` Edge Function over pg_net.
-- 3. `notify-push` looks up every FCM token of the recipient and delivers a
--    real-time push so it arrives even when the app is minimised or closed.
--
-- One-time setup (SQL editor, run as postgres)
-- --------------------------------------------
-- The webhook URL + shared secret live in the single-row private table
-- `app_private.push_config`, which the SECURITY DEFINER trigger reads. This
-- avoids `ALTER DATABASE ... SET app.*`, which fails with ERROR 42501 in the
-- hosted Supabase SQL Editor (the `postgres` role there is not a superuser).
-- To configure the webhook, run the upsert from PUSH_NOTIFICATIONS_SETUP.md:
--   insert into app_private.push_config (singleton, url, webhook_secret)
--   values (true, 'https://<project-ref>.supabase.co/functions/v1/notify-push',
--           '<PUSH_WEBHOOK_SECRET>')
--   on conflict (singleton) do update
--     set url = excluded.url,
--         webhook_secret = excluded.webhook_secret,
--         updated_at = now();
-- Then deploy the Edge Function and set its secrets:
--   supabase functions deploy notify-push
--   supabase secrets set FCM_SERVICE_ACCOUNT_JSON='...full service account JSON...'
--   supabase secrets set PUSH_WEBHOOK_SECRET='...'  (same value as config.webhook_secret)
--
-- The triggers are inert (no-ops) until the config row has a non-empty url.

-- ---------------------------------------------------------------------------
-- 1. FCM device tokens
-- ---------------------------------------------------------------------------

create table if not exists public.fcm_tokens (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  token text not null unique,
  platform text not null default 'android',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists fcm_tokens_user_idx
  on public.fcm_tokens (user_id);
create index if not exists fcm_tokens_tenant_idx
  on public.fcm_tokens (tenant_id);

alter table public.fcm_tokens enable row level security;

drop policy if exists fcm_tokens_select on public.fcm_tokens;
create policy fcm_tokens_select on public.fcm_tokens
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists fcm_tokens_insert on public.fcm_tokens;
create policy fcm_tokens_insert on public.fcm_tokens
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists fcm_tokens_update on public.fcm_tokens;
create policy fcm_tokens_update on public.fcm_tokens
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists fcm_tokens_delete on public.fcm_tokens;
create policy fcm_tokens_delete on public.fcm_tokens
  for delete to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 2. Dedicated low stock alerts
--    Fires on INSERT and on stock/threshold changes. Protection against
--    duplicate spam: only the transition into "at or below threshold"
--    creates an alert, and the dedupe key limits it to one per product per
--    business day (the unique (user_id, dedupe_key) constraint enforces it).
-- ---------------------------------------------------------------------------

create or replace function public.notify_low_stock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_date_key text := to_char((now() at time zone 'utc'), 'YYYY-MM-DD');
  v_dedupe_key text;
  v_qty_label text;
  v_recipient record;
begin
  -- Inactive products never alert.
  if not coalesce(new.is_active, true) then
    return new;
  end if;

  -- Only alert when stock is at or below the minimum threshold.
  if new.stock_qty > new.low_stock_threshold then
    return new;
  end if;

  -- Stock was already at/below the threshold with an unchanged threshold:
  -- it was alerted when it dropped (or on insert) — do not spam again.
  if TG_OP = 'UPDATE'
     and old.stock_qty <= old.low_stock_threshold
     and old.low_stock_threshold = new.low_stock_threshold then
    return new;
  end if;

  v_qty_label :=
    case
      when new.stock_qty = floor(new.stock_qty)
        then (new.stock_qty)::int::text
      else (round(new.stock_qty, 2))::text
    end;
  v_dedupe_key := 'low_stock:' || new.tenant_id || ':' || new.id || ':' || v_date_key;

  for v_recipient in
    select m.user_id
    from public.tenant_members m
    where m.tenant_id = new.tenant_id
      and m.role in ('admin', 'manager')
      and m.is_active
  loop
    insert into public.app_notifications
      (tenant_id, user_id, title, body, kind, reference_id, dedupe_key)
    values
      (new.tenant_id,
       v_recipient.user_id,
       'Low stock alert',
       new.name || ' is running low — only ' || v_qty_label || ' ' ||
         coalesce(new.unit, 'pcs') ||
         ' left (alert threshold: ' || new.low_stock_threshold ||
         '). Reorder soon.',
       'low_stock',
       new.id,
       v_dedupe_key)
    on conflict (user_id, dedupe_key) do nothing;
  end loop;

  return new;
end $$;

drop trigger if exists products_low_stock_notify on public.products;
create trigger products_low_stock_notify
after insert or update of stock_qty, low_stock_threshold, is_active
on public.products
for each row
execute function public.notify_low_stock();

-- ---------------------------------------------------------------------------
-- 3. Private webhook configuration
--    The hosted Supabase SQL Editor runs as `postgres`, which is NOT a
--    superuser, so `ALTER DATABASE ... SET app.*` fails with 42501. Keep the
--    webhook settings in a single-row table in a non-exposed schema instead.
--    New schemas are not exposed by PostgREST, RLS is enabled with no policies,
--    and all role grants are revoked — only this SECURITY DEFINER function
--    (owned by postgres) can read the row.
-- ---------------------------------------------------------------------------

create schema if not exists app_private;

create table if not exists app_private.push_config (
  singleton boolean primary key default true check (singleton),
  url text,
  webhook_secret text,
  updated_at timestamptz not null default now()
);

alter table app_private.push_config enable row level security;
revoke all on schema app_private from public;
revoke all on app_private.push_config from public, anon, authenticated, service_role;

-- Keep exactly one config row. A NULL url means "not configured yet", which
-- keeps the trigger a no-op until the real values are upserted (see the guide).
insert into app_private.push_config (singleton, url, webhook_secret)
values (true, null, null)
on conflict (singleton) do nothing;

-- ---------------------------------------------------------------------------
-- 4. Real-time push webhook
--    Every new app_notifications row is POSTed to the notify-push Edge
--    Function, which fans the message out over FCM. Failures must never
--    block the notification insert, so errors are swallowed.
-- ---------------------------------------------------------------------------

do $$ begin
  create extension if not exists pg_net;
exception when others then
  raise notice 'pg_net unavailable: %', sqlerrm;
end $$;

create or replace function public.notify_push_webhook()
returns trigger
language plpgsql
security definer
set search_path = public, net, app_private
as $$
declare
  v_url text;
  v_key text;
begin
  -- Read the webhook config from the private single-row table. SECURITY
  -- DEFINER (owned by postgres) lets this function read the restricted table
  -- even though no client role has any grant on it.
  select url, webhook_secret
    into v_url, v_key
    from app_private.push_config
   where singleton;

  -- Not configured yet: keep the in-app notification, skip the push.
  if v_url is null or v_url = '' then
    return new;
  end if;

  begin
    perform net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || coalesce(v_key, '')
      ),
      body := jsonb_build_object('type', TG_OP, 'record', to_jsonb(new))
    );
  exception when others then
    -- A failed webhook must never break writes.
    null;
  end;

  return new;
end $$;

drop trigger if exists app_notifications_push on public.app_notifications;
create trigger app_notifications_push
after insert
on public.app_notifications
for each row
execute function public.notify_push_webhook();
