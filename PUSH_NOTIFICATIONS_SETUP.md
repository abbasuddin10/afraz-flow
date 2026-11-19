# Afraz Flow — Push Notifications Setup Guide

This guide covers everything that must be configured **outside the code** before
push notifications arrive on a real device. The Dart/Flutter, Android, iOS and
Supabase-side code has already been audited and fixed in this repository.

```
Device  →  FCM token saved in Supabase `fcm_tokens`
        →  new row in `app_notifications` fires a Postgres trigger
        →  pg_net POSTs the row to the `notify-push` Edge Function
        →  Edge Function calls FCM HTTP v1 with a service account
        →  notification appears on the device
```

> **Important:** the app only registers a device token when the user is signed
> into a **cloud (Supabase)** account. The offline **demo workspace** never
> registers a token — this is intentional.

---

## Part 1 — Firebase Console

### 1. Create / open the Firebase project

1. Go to <https://console.firebase.google.com/> and choose **Add project**
   (or open the project that is already linked to Supabase).
2. Note the **Project ID** (you will need it later, e.g. `afraz-flow-12345`).
3. Make sure the project has a default Google Cloud project behind it (it does
   by default).

### 2. Enable the Cloud Messaging API (V1)

1. Open <https://console.cloud.google.com/> with the **same** project selected.
2. Go to **APIs & Services → Library**.
3. Search for **Firebase Cloud Messaging API** and click **Enable**.
   (The legacy "FCM for Web Push / Legacy" API is not used — the Edge Function
   uses the modern HTTP v1 endpoint.)

### 3. Register the Android app and download `google-services.json`

1. In Firebase Console → **Project settings** (gear icon) → **Your apps** →
   **Add app → Android**.
2. Android package name: **`com.afrazstudio.flow`**
   (this exactly matches `applicationId` in `android/app/build.gradle.kts`).
3. Register the app, then **download `google-services.json`**.
4. Copy it to:

   ```
   D:\flutter files\Afraz Flow\android\app\google-services.json
   ```

5. **Rebuild from scratch** — the Google Services Gradle plugin is applied
   only when this file is present at build time:

   ```powershell
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

   Hot reload / hot restart is **not** enough. Uninstall the old APK from the
   phone before installing the new one.

> If the file is missing, `Firebase.initializeApp()` fails silently, the
> service stays disabled (`available == false`), no token is saved, and no push
> can ever arrive. This is the single most common cause of "notifications not
> arriving".

### 4. (iOS) Register the app, add the plist and configure APNs

Skip this section if you only ship Android.

1. Firebase Console → **Project settings → Your apps → Add app → iOS**.
2. Bundle ID: **`com.afrazstudio.flow`**
   (matches `PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj`).
3. Download **`GoogleService-Info.plist`** and add it to `ios/Runner/` in Xcode
   with **"Add to targets: Runner"** checked.
4. Firebase Console → **Cloud Messaging** → **Apple app configuration** →
   upload your **APNs Authentication Key (.p8)** (requires an Apple Developer
   account with the Key ID and Team ID).
5. Open `ios/Runner.xcodeproj` in Xcode → **Signing & Capabilities**:
   - add **Push Notifications**
   - add **Background Modes** → check **Remote notifications**
6. Install the CocoaPods dependencies (a `Podfile` has been added/restored,
   targeting iOS 15+, which `firebase_core 5.x` requires):

   ```powershell
   cd ios
   pod install
   cd ..
   ```

### 5. Generate a Firebase service account JSON (used by Supabase)

This is how the server is allowed to send messages through FCM HTTP v1.

1. Firebase Console → **Project settings → Service accounts**.
2. Click **Generate new private key** → confirm → a JSON file downloads.
3. Keep this file safe — it is the `FCM_SERVICE_ACCOUNT_JSON` secret below.
   (Alternative: Google Cloud Console → **IAM & Admin → Service Accounts** →
   the `firebase-adminsdk-…` account → **Keys → Add key → Create new key → JSON**.)

---

## Part 2 — Supabase

The CLI is already linked to project `jryuyaehhpfbxpvrzdeg`
(`supabase/.temp/project-ref`), so the commands below target the correct
project.

### 1. Apply the push-notification migration

Run `supabase/migrations/0005_push_notifications.sql` in the Supabase
**SQL Editor** (or `supabase db push` if your local project is in sync).
The script is idempotent (`create ... if not exists` / `create or replace`),
so it is safe to re-run if you already applied an older version.

It creates:

- `public.fcm_tokens` + RLS policies (a user can only manage their own tokens)
- `notify_low_stock()` + `products_low_stock_notify` trigger
- `app_private.push_config` — a single-row, private config table (see step 2)
- `notify_push_webhook()` + `app_notifications_push` trigger

### 2. Configure the database webhook settings

> **Why not `ALTER DATABASE ... SET app.*`?** The hosted Supabase SQL Editor
> runs as `postgres`, which is **not** a superuser. `ALTER DATABASE postgres SET
> app.notify_push_url = ...` therefore fails with `ERROR: 42501: permission
> denied to set parameter`. The trigger now reads its settings from a small
> private table instead, so it only needs ordinary `CREATE TABLE` permissions
> that the SQL Editor already has.

The migration created `app_private.push_config` with one row. In the Supabase
**SQL Editor**, upsert the real values into it:

```sql
insert into app_private.push_config (singleton, url, webhook_secret)
values (
  true,
  'https://jryuyaehhpfbxpvrzdeg.supabase.co/functions/v1/notify-push',
  'REPLACE_WITH_A_LONG_RANDOM_SECRET'   -- generate with: openssl rand -hex 32
)
on conflict (singleton) do update
set url = excluded.url,
    webhook_secret = excluded.webhook_secret,
    updated_at = now();

-- Confirm it was saved:
select url, webhook_secret, updated_at from app_private.push_config;
```

The `app_private` schema is **not exposed** by the Data API, the table has RLS
enabled with no policies, and all grants to `anon`, `authenticated` and
`service_role` are revoked. Only the `SECURITY DEFINER` trigger function
(owned by `postgres`) can read it, so the secret is never reachable from the
client. The trigger is a no-op until the config row has a non-empty `url`.

### 3. Set Edge Function secrets

Dashboard → **Edge Functions → Secrets**, or via CLI:

```powershell
supabase secrets set FCM_SERVICE_ACCOUNT_JSON='<paste the entire JSON file here>'
supabase secrets set PUSH_WEBHOOK_SECRET='REPLACE_WITH_A_LONG_RANDOM_SECRET'
```

`PUSH_WEBHOOK_SECRET` **must be identical** to `webhook_secret` in
`app_private.push_config` from step 2.

> `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically into
> every Supabase Edge Function — you do **not** need to set them yourself. The
> Edge Function uses the service-role key to read `fcm_tokens` (RLS bypass).

> Windows PowerShell tip: for long JSON, prefer the Dashboard "Add new secret"
> form. If you use the CLI, wrap the JSON in single quotes and keep the
> `private_key` value as a valid JSON string (the `\n` escapes are fine).

### 4. Deploy the Edge Function

```powershell
supabase functions deploy notify-push --no-verify-jwt
```

`--no-verify-jwt` is essential: the caller is the Postgres `pg_net` trigger, not
a logged-in Supabase user. A committed `supabase/config.toml` also declares
`verify_jwt = false` for `notify-push`. If JWT verification remains enabled,
every webhook call is rejected with **401** before the function code runs.

### 5. Verify end to end

**a. Check that the device registered a token.** Sign into the cloud app on the
phone, then in SQL Editor:

```sql
select user_id, platform, token, updated_at from public.fcm_tokens;
```

You should see one row for the phone. If the table is empty, re-check
`google-services.json`, the rebuild, and that the account is not the demo
workspace.

**b. Call the function directly** (Dashboard → Edge Functions → notify-push →
Invoke, or curl):

```powershell
curl -X POST `
  'https://jryuyaehhpfbxpvrzdeg.supabase.co/functions/v1/notify-push' `
  -H 'Authorization: Bearer REPLACE_WITH_A_LONG_RANDOM_SECRET' `
  -H 'Content-Type: application/json' `
  -d '{"type":"INSERT","record":{"user_id":"<YOUR_PROFILE_UUID>","title":"Test push","body":"Hello from Afraz Flow","kind":"low_stock","reference_id":""}}'
```

Expected response: `{"sent":1,"stale":0,"failed":0}`.

- `sent: 0, detail: "No registered devices."` → token was never saved (Part 2.5a).
- HTTP 401 → JWT verification is still on, or the two secrets do not match.
- FCM error 403 in function logs → service-account permissions or the Cloud
  Messaging API is not enabled / project needs billing.

**c. Trigger a real alert.** In the app, edit a product so `stock_qty` drops to
or below `low_stock_threshold`. The `notify_low_stock()` trigger inserts an
`app_notifications` row, which fires the push webhook. You can also generate a
Daily AI Briefing (kind `daily_briefing`).

---

## Troubleshooting checklist

| Symptom | Likely cause |
|---|---|
| No token row in `fcm_tokens` | `google-services.json` missing at build time; app rebuilt incorrectly; signed into demo, not cloud |
| Function returns 401 | `verify_jwt` still true, or `PUSH_WEBHOOK_SECRET` ≠ `app_private.push_config.webhook_secret` |
| `ERROR: 42501: permission denied to set parameter "app.notify_push_url"` | An old copy of the setup used `ALTER DATABASE ... SET app.*`. Follow step 2 above and upsert into `app_private.push_config` instead — no database-level setting is needed |
| Function returns `failed: 1`, FCM 403 | Service account lacks FCM permission, or Cloud Messaging API disabled |
| Function returns `stale: 1` | Token expired/app uninstalled — the row is deleted automatically; reopen the app to re-register |
| Token exists, function says `sent: 1`, nothing on phone | Device notification permission denied (Android 13+), battery optimisation, or Do Not Disturb. Check logcat for "FCM background message received" / "Local notification" |
| Foreground: no visible banner | The app mirrors foreground pushes itself via `flutter_local_notifications`; ensure notification permission was granted at first launch |
| Tapping the push does not open the right page | Confirmed by `FLUTTER_NOTIFICATION_CLICK` intent filter (Android) and `getInitialMessage` handling (Dart) — reinstall after adding the manifest entry |
| iOS: no token / no alert | APNs key not uploaded, Push Notifications capability missing, `GoogleService-Info.plist` not in the Runner target, or `pod install` not run |

---

## What was fixed in code (for reference)

- **Web AppBar:** the `low stock` / `to ship` chips are now always rendered in
  the desktop/web top bar (previously only when the count was > 0).
- **`push_notification_service.dart`:** the background handler now displays
  data-only pushes as local notifications; token registration is deterministic.
- **`auth_controller.dart`:** requests FCM token registration immediately after
  a successful cloud sign-in/register.
- **`AndroidManifest.xml`:** added the `FLUTTER_NOTIFICATION_CLICK` intent
  filter matching the Edge Function's `click_action`.
- **iOS:** restored the missing `Podfile` (iOS 15+), added
  `FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()` to
  `AppDelegate.swift`, the required bridging-header imports, and the
  `remote-notification` background mode; bumped the deployment target to iOS 15.
- **`supabase/config.toml`:** added with `verify_jwt = false` for `notify-push`.
