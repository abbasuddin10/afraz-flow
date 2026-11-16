# Afraz Flow

Afraz Flow is a multi-tenant business management and courier tracking app built
with Flutter, GetX and Supabase. One codebase runs on Android, iOS, Web, macOS,
Windows and Linux with a responsive interface: bottom navigation and list-first
screens on phones, and sidebar navigation with master–detail layouts and tables
on desktop.

| | |
| --- | --- |
| **App name** | Afraz Flow |
| **Bundle / application id** | `com.afrazstudio.flow` |
| **Dart package** | `afraz_flow` |
| **Version** | 1.0.0+1 |
| **Flutter** | 3.32.7 (Dart 3.8.1) |

## Modules

- **Dashboard** — revenue, expenses, profit inputs, receivables/payables, sales
  trend chart, top products, low-stock alerts, recent sales, active deliveries
  and pending COD, filtered by day/week/month/quarter.
- **Inventory** — product catalogue, barcode/SKU search, low-stock filters,
  stock in/out/adjustment with movement history, archive/reactivate, barcode
  scanner, and per-product thresholds.
- **POS** — product search and scanner, cart with quantity/price editing,
  discounts and tax, cash/card/bank/credit payments, customer (khata) accounts,
  invoice generation, PDF receipt preview and printing.
- **Ledger & cash book** — customer and supplier accounts, charge/payment
  entries, outstanding balances, expenses by category, and a unified daily cash
  book.
- **Courier** — COD delivery orders, carrier and tracking numbers, status flow
  (pending → shipped → delivered / returned / cancelled), event timeline, and
  COD reconciliation after delivery.
- **Staff** — team list, invitation by email, role changes
  (Admin/Manager/Cashier), and activation/deactivation with a guard that keeps
  at least one active admin.
- **AI Assistant (admin)** — a Gemini-backed chat in English or Bangla. It turns
  a question into one read-only SQL query, runs it through an RLS-enforced
  Postgres RPC, then replies with a conversational summary, a structured result
  table and the generated query.
- **Daily AI briefing (admin)** — an automated executive summary at the
  business's chosen local time (default 10:00 PM). It compiles sales, expenses,
  net profit, cash collected, new credit, top products, low-stock alerts and
  auto-reorders, asks Gemini for a short narrative, stores it in
  `daily_summaries`, and pushes an in-app notification. The dashboard card,
  history browser, notification bell and schedule settings make it easy to
  review every day's briefing.
- **Settings** — business profile, business type/currency, tax rate, low-stock
  threshold, light/dark/system theme, session info, sign out, demo reset and
  diagnostics.

Roles are enforced in the UI (cashiers cannot open finance/team/settings,
managers cannot manage the team or settings) and again by Row Level Security in
Postgres.

## Data modes

The app has two backends and picks one at runtime:

- **Cloud (Supabase)** — the default whenever credentials are configured. Every
  read and write goes to your Supabase project.
- **Local demo** — a fully seeded workspace stored only on the device
  (`SharedPreferences`). It is always reachable from the login screen via
  **Explore the demo workspace**, so reviewers can try every module without an
  account or a backend. It never uploads anything.

The choice persists per device. Signing out of the demo returns the app to cloud
sign-in. If credentials are missing or Supabase fails to initialise, the app
starts in demo mode and shows why on the login screen.

Demo sign-in:

- **Email:** `demo@afrazflow.app`
- **Password:** `demo1234`

The demo data set includes low-stock products, a 14-day sales curve, customer
and supplier khata balances, expenses, credit sales and six courier orders at
different statuses, plus a sample daily briefing, auto-reorders and an unread
in-app notification. **Settings → Reset demo data** restores it.

> Demo mode is for evaluation only. Local demo passwords are stored in plain
> text in `SharedPreferences`; never use it with real business data.

## Quick start (offline demo)

No backend or credentials are required to explore the product:

```bash
flutter pub get
flutter run -d windows   # or chrome, android, ios, macos, linux
```

Then tap **Explore the demo workspace** on the login screen (or use the demo
credentials above).

## Supabase setup (production)

### 1. Create the project

Create a project at [supabase.com](https://supabase.com). Enable email auth
under **Authentication → Providers**. If **Confirm email** is on, users must
confirm their address before the app can load their organization; registration
stores the business profile in user metadata and provisions the organization on
the first successful sign-in.

### 2. Apply the schema

The full schema, indexes, Row Level Security policies and transactional RPCs
live in [`supabase/migrations/0001_init.sql`](supabase/migrations/0001_init.sql).
The AI assistant gateway is added by
[`supabase/migrations/0002_ai_assistant.sql`](supabase/migrations/0002_ai_assistant.sql),
and the daily briefing schema, RPCs and Realtime publication by
[`supabase/migrations/0003_daily_briefing.sql`](supabase/migrations/0003_daily_briefing.sql).

With the Supabase CLI:

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

Or paste the migration files into the project's **SQL Editor** in order and run
each once. The schema migration creates:

- `tenants`, `profiles`, `tenant_members`
- `products`, `stock_movements`
- `sales`, `sale_items`
- `ledger_accounts`, `ledger_entries`, `expenses`
- `courier_orders`, `courier_events`
- `daily_summaries`, `inventory_reorders`, `app_notifications` (migration 0003)
- an `auth.users` trigger that creates the matching `profiles` row
- RPCs `create_organization`, `checkout_sale`, `adjust_stock` and
  `record_ledger_entry`
- briefing RPCs `build_daily_business_snapshot`, `trigger_daily_reorders` and
  `list_due_daily_summaries` (migration 0003)

### 3. Deploy the staff invitation function

Staff invitations use a server-side Edge Function so the service-role key never
reaches the client. Remote invites create the Supabase auth account with the
temporary password entered by the admin (or `Welcome123` when none is entered),
send a confirmation email, and add the membership. The cashier confirms their
email, then signs in with that temporary password.

```bash
supabase functions deploy invite-staff
# Optional: set the URL that invite emails return to.
supabase secrets set APP_URL=https://app.example.com
```

Hosted projects automatically provide `SUPABASE_URL`, `SUPABASE_ANON_KEY` and
`SUPABASE_SERVICE_ROLE_KEY` to functions. The function checks that the caller is
an active **admin** of the target tenant before inviting anyone.

### 4. Deploy the AI assistant

The assistant uses Google Gemini to translate a question into SQL and a
Postgres RPC (`ai_assistant_query`) to execute it safely.

1. Apply the assistant migration (it creates the read-only gateway function):

   ```bash
   supabase db push
   ```

2. Create a Gemini API key in [Google AI Studio](https://aistudio.google.com/apikey).

3. Store the key as a function secret and deploy:

   ```bash
   supabase secrets set GEMINI_API_KEY=<your-key>
   # Optional: override the default model (gemini-3.6-flash)
   supabase secrets set GEMINI_MODEL=gemini-3.6-flash
   supabase functions deploy ai-assistant
   ```

How the safety model works:

- Only an active **admin** of the workspace can call the function (checked with
  the caller's JWT, not a client-supplied role).
- Gemini may only return a single `SELECT`/`WITH` statement. The Edge Function
  and the Postgres RPC both reject comments, extra statements, write/DDL
  keywords, row locks, protected schemas/functions, and queries that are not
  explicitly scoped to the current `tenant_id`. A single trailing semicolon is
  tolerated and stripped.
- The query runs through `ai_assistant_query`, which is `SECURITY INVOKER` and
  uses the caller's JWT. Every existing RLS policy still applies, so the AI
  cannot read another tenant's rows even if it generates a bad query.
- Results are capped at 200 rows and queries time out after 8 seconds.
- The service-role key is never used for AI data access, and the Gemini key
  stays inside the Edge Function.

Verify the shared SQL guard locally before deploying:

```bash
deno check --no-lock supabase/functions/ai-assistant/index.ts
deno test --no-lock supabase/functions/ai-assistant/sql_guard_test.ts
```

The Flutter chat UI appears as **AI Assistant** in the sidebar for admins (and
under **More** on phones). It supports English and Bangla questions, loading
states, follow-up suggestions, structured tables and a collapsible view of the
generated query.

### 5. Deploy the daily briefing

The daily briefing is generated by the `daily-briefing` Edge Function. An admin
can invoke it from the app, or a scheduler can invoke it with the service-role
key.

```bash
supabase db push
supabase functions deploy daily-briefing --no-verify-jwt
supabase secrets set GEMINI_API_KEY=<your-key>
# Optional: override the default model
supabase secrets set GEMINI_MODEL=gemini-3.6-flash
```

The function verifies the caller when invoked manually, raises idempotent
reorders for low-stock products, builds the day's snapshot through
`build_daily_business_snapshot`, asks Gemini for the narrative, stores it in
`daily_summaries` and writes one in-app notification per active admin.

Schedule the hourly check with pg_cron + pg_net (or your own scheduler). The job
only generates briefings whose local delivery time has passed:

```sql
select cron.schedule(
  'daily-briefing',
  '5 * * * *',
  $$
  select net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/daily-briefing',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer <service-role-key>'
    ),
    body := '{"mode":"batch"}'::jsonb
  );
  $$
);
```

`app_notifications` is in the Supabase Realtime publication, so the bell updates
without a refresh. Admins can change the delivery time and timezone in
**Settings → Daily AI briefing**, or generate today's summary immediately from
the dashboard card or the briefing page.

### 6. Run the app against Supabase

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-or-publishable-key>
```

Release builds:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

flutter build web --release \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

flutter build windows --release \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

> **Important:** `lib/core/config/app_config.dart` ships a *default* URL and key
> (`https://jryuyaehhpfbxvrzdeg.supabase.co`). That project must exist and match
> your own; if it does not resolve, every cloud call fails with
> *"No connection"*. Replace the defaults with your project's URL and key, or
> always pass them with `--dart-define` as above. `SUPABASE_URL` must be the bare
> `https://<ref>.supabase.co` origin (no trailing slash or `/rest/v1`).

If Supabase is not configured or fails to initialise, the app logs the error and
starts in the local demo workspace instead of a blank screen; the login screen
explains why and offers **Back to cloud sign-in** once credentials work. Check
**Settings → About → Data mode** to confirm which backend is active.

> The client accepts either the legacy anon key or the newer publishable key in
> `SUPABASE_ANON_KEY`. Both are safe to expose; RLS is the security boundary.

## Tenant isolation and security

Every business table has a `tenant_id` foreign key and RLS enabled. Queries in
the app add `tenant_id` filters as defence in depth, but access is enforced in
Postgres through:

- `is_tenant_member(tenant_id)` — active membership required to read rows.
- `has_tenant_role(tenant_id, roles)` — write policies for catalog, finance and
  team management.
- `shares_tenant_with(user_id)` — lets teammates see each other's profiles
  without exposing other tenants.

Write policies by role:

| Area | Admin | Manager | Cashier |
| --- | --- | --- | --- |
| Products / stock | write | write | read |
| Sales | write | write | write |
| Ledger / expenses | write | write | read |
| Courier | write | write | write |
| Team / settings | write | read | read |

All multi-row operations that must stay consistent — checkout (sale + items +
stock + movements + ledger charge), stock adjustment and ledger posting — run
inside `SECURITY DEFINER` Postgres functions in a single transaction. A network
failure can therefore never leave stock partially decremented.

Additional safeguards:

- The service-role key is used only inside the `invite-staff` Edge Function.
- RPCs validate the caller's membership and role server-side; they do not trust
  `tenant_id` supplied by the client.
- Checkout rejects insufficient stock and negative amounts, and requires an
  account for any outstanding balance.
- Ledger payments cannot exceed the outstanding balance.
- The last active admin of an organization cannot be demoted or deactivated.
- The AI assistant is admin-only, read-only and tenant-scoped; its Postgres
  gateway is `SECURITY INVOKER`, so RLS remains the final boundary.

## Architecture

Feature-first Clean Architecture with GetX:

```
lib/
  app.dart, main.dart, app_bootstrap.dart    # root widget, bootstrap, DI graph
  core/
    config/            # app + Supabase configuration
    data/              # DataStore abstraction, Supabase + local stores, demo seed
    models/            # Tenant, AppUser, Membership, Account, LedgerEntry
    platform/          # desktop window sizing
    services/          # preferences, theme, session, PDF receipts
    theme/             # Material 3 design system, colours, typography
    utils/             # formatters, validators, failures, JSON helpers
    widgets/           # shared cards, headers, states, dialogs, search
  features/
    auth/ inventory/ pos/ ledger/ courier/ staff/ dashboard/ settings/
    assistant/      # Gemini chat, repository, controller, responsive view
    briefing/       # daily executive summary models, repository, card + view
    notifications/  # in-app notification inbox, realtime and bell widget
      data/            # models + repositories
      controllers/     # GetX controllers
      bindings/        # lazy dependency registration
      views/           # responsive screens and dialogs
  routes/              # GetX pages, AuthMiddleware
  supabase/ (repo root) migrations + Edge Functions
```

- `DataStore` isolates the app from Supabase. Repositories never import
  `supabase_flutter`, which keeps the domain testable offline.
- `SessionService` holds the active tenant/user/membership and is the source of
  the `tenant_id` used by repositories.
- The shell switches sections in place (sidebar, navigation rail, or bottom
  navigation) while module controllers are created lazily by `ShellBinding`.
- All money, stock and date formatting goes through `Formats`, so a workspace
  uses one currency and locale consistently.

## Responsive behaviour

- **Mobile:** bottom navigation for Dashboard, POS, Inventory and Courier, with
  a **More** sheet for Ledger, Staff, AI Assistant, Daily AI Briefing and
  Settings; drawers for secondary actions; card/list layouts and full-screen
  dialogs.
- **Tablet:** navigation rail and two-column forms.
- **Desktop:** permanent sidebar, master–detail inventory/courier, data tables
  and constrained content widths. The window opens at 1280×820 with a minimum
  size of 1024×700.

## Barcode scanning

`mobile_scanner` powers scanning on Android, iOS, macOS and Web (camera
permission is requested at runtime). Windows and Linux builds show a manual
code-entry panel instead, because the scanner plugin has no desktop camera
implementation there. Every platform also exposes manual entry as a fallback,
and scanning accepts either a barcode or a SKU.

## Receipts and printing

POS receipts are generated as PDFs with `pdf` and sent to the platform print
dialog with `printing`. Users can preview before printing and share/save the PDF
where the platform supports it. Invoice numbering uses the local date plus a
daily sequence (`INV-YYYYMMDD-NNN`); courier orders use `AF-YYMMDD-HHMM`.

## Testing

```bash
flutter analyze
flutter test
```

The test suite covers validators/formatters, local demo authentication and
session restore, tenant-scoped product queries, checkout stock/ledger writes,
oversell rejection, COD reconciliation, cross-tenant isolation, settings
persistence, demo reset, shared widget states and the desktop scanner fallback.
Unit tests use the local backend so they run without network access.

## Platform configuration

- **Android:** minSdk 23, multidex, internet + camera permissions, Material 3
  launch/theme resources, `compileSdk` 36 and NDK 27 required by
  `mobile_scanner` 7.5 and AndroidX Camera 1.6.
- **iOS:** camera and photo usage descriptions; supports iPhone and iPad.
- **macOS:** camera, network client and user-selected file entitlements.
- **Windows/Linux:** native window title and minimum size configured at startup.
- **Web:** responsive loading shell, installable web manifest, theme colour and
  app metadata.

`fl_chart` is pinned to 0.71.0 because 1.1.x calls
`Matrix4.translateByDouble` / `scaleByDouble`, which require `vector_math` 2.2+;
Flutter 3.32 pins 2.1.4. The chart API used by the dashboard is identical in
0.71.0, so the pin can be lifted after upgrading to a Flutter SDK that bundles a
newer `vector_math`.

## Known limitations

- Courier status is managed manually inside Afraz Flow; there is no direct
  integration with TCS/Leopard/M&P tracking APIs yet. Tracking numbers and
  timelines are stored locally in your Supabase project.
- A user with memberships in multiple organizations signs into the first active
  one; an organization switcher is not included in this release.
- Business logo upload is not implemented; the `logo_url` column is ready for a
  future Storage integration.
- Demo-mode credentials are not secure by design and must not be used with real
  business data.

## Support

Afraz Studio — `support@afrazstudio.com`
