# The Grids

*Smart Living. Smart Spaces.* A housing-society management app for India,
for admins, owners and tenants.

| Part | Stack |
|---|---|
| App (`/`) | Flutter, Riverpod 3, go_router, Dio, flutter_secure_storage |
| API (`/backend`) | Node.js, NestJS 12, Prisma 7, MySQL 8.4 |

Everything in the original spec is built (7 phases): phone-OTP sign-in with
three roles; Home and Tower (visitors, notices, neighbours, facility booking,
complaints, events, weather); Maintenance/Rent with Razorpay checkout,
server-side verification and PDF receipts; Community (polls, clubs,
announcements); Profile (household, services, payment and notification
preferences, tenant info, account deletion); notifications with FCM push; eight
Indian languages; light and dark themes; offline viewing.

What still needs credentials or a decision before launch is listed under
[Before launch](#before-launch).

## How payments work

1. The app asks the API for an order (`POST /v1/payments/orders`). The server
   checks the due belongs to the caller's flat and creates a Razorpay order for
   the amount it has on record. The app never decides the amount.
2. Razorpay Checkout opens (UPI with Google Pay/PhonePe, cards, net banking,
   wallets). Card numbers and CVV are typed into Razorpay's own screen; the app
   never sees or stores them.
3. The app sends Razorpay's signature to `POST /v1/payments/verify`. The server
   checks `HMAC-SHA256(order_id|payment_id, key_secret)` and fetches the payment
   from Razorpay before marking the due paid.
4. Razorpay also calls `POST /v1/payments/webhook` (HMAC over the raw body with
   the webhook secret). It settles payments the app never reported, e.g. when
   the phone lost signal or the user paid from an external wallet. Settling
   happens at most once, whichever arrives first.
5. The receipt PDF (`MNT/2026/10/0007` numbering per society per month) is
   generated on the server on first download and stored under `storage/receipts`.

**No Razorpay keys yet?** In development the API falls back to a *simulated
gateway*. It signs payments with its own secret, so verification, receipts
and the UI run for real, and the app shows a "Test checkout" sheet instead of
Razorpay. Production refuses to start without `RAZORPAY_KEY_ID`,
`RAZORPAY_KEY_SECRET` and `RAZORPAY_WEBHOOK_SECRET`, and prod app builds refuse
simulated checkouts.

## How sign-in works

1. Pick a society, then a role (Admin, Member (Owner) or Tenant), then enter a
   mobile number.
2. The API sends a 6-digit code, but only to numbers an admin (or the flat's
   owner) has registered for that society and role. Otherwise it answers
   **"Not registered – contact your society admin"**.
3. A correct code returns a short-lived access token (15 min) and a rotating
   refresh token (30 days, stored in the Android Keystore / iOS Keychain).
   If an old refresh token is ever replayed, the whole session is revoked.

There are no passwords anywhere, and no Aadhaar numbers are collected or stored.
In development the code is printed in the API log. The dev app also shows it,
with a "Use code" button.

## Prerequisites (Windows)

| Tool | Where it is on this machine |
|---|---|
| Flutter 3.47 | `C:\flutter` (the path must not contain spaces) |
| Android SDK + emulator | `%LOCALAPPDATA%\Android\Sdk`, AVD `Pixel_8_API_36` |
| JDK 21 | `%USERPROFILE%\.jdks\temurin-21` |
| Node.js 24 | system install |
| MySQL 8.4 (portable, no Docker) | `%USERPROFILE%\mysql` |

## Run everything (VS Code)

1. **Tasks → MySQL: start** (or run `%USERPROFILE%\mysql\start-mysql.cmd`).
2. **Tasks → Backend: start (watch)**. The API listens on `http://localhost:3000`.
3. Start the emulator with the *Android iOS Emulator* extension → `Pixel_8_API_36`.
4. **Run → "The Grids (dev)"**.

From a terminal instead:

```sh
cd backend
npm install                 # also generates the Prisma client
npm run db:migrate          # first time: creates the tables
npm run db:seed             # demo data (wipes and re-creates)
npm run start:dev

cd ..
flutter run --flavor dev -t lib/main_dev.dart
```

The dev app calls `http://10.0.2.2:3000`, which is your PC as seen from the
Android emulator. On a physical phone on the same Wi-Fi, use
`--dart-define=API_BASE_URL=http://<your-PC-IP>:3000`.

### Demo logins (society: Sai Icon Co-operative Society)

| Role | Name | Mobile |
|---|---|---|
| Admin, and Owner of Tower-C 502 | Shruti Chetan Dalvi | 90000 00001 |
| Owner | Riya Mehta | 90000 00002 |
| Tenant | Shreyas Kulkarni | 91000 00001 |
| Owner (invited, never signed in) | Nikhil Joshi | 90000 00020 |

Shruti can switch between Admin and Owner from the drawer.

## Flavors

| | dev | prod |
|---|---|---|
| Entry point | `lib/main_dev.dart` | `lib/main_prod.dart` |
| Android app id | `com.thegrids.the_grids.dev` | `com.thegrids.the_grids` |
| Launcher name | The Grids Dev | The Grids |
| API | `http://10.0.2.2:3000` | `https://api.thegrids.app` (placeholder) |
| Extras | DEV banner, OTP shown in app | none |

iOS schemes for the flavors need Xcode on a Mac and aren't set up yet.

## Offline use

Every screen keeps the last data it loaded (saved per account and role in the
app's private storage). Without a connection the app shows that data with a
"You're offline — showing saved data" strip, and it even opens offline after a
restart. Actions that change something (paying, voting, booking…) need a
connection and say so. Signing out wipes the saved data, so the next person on a
shared phone sees nothing.

## Accessibility

- Every tap target is at least 48 dp and has a screen-reader label; status
  chips, poll results and stats read as one sentence each.
- Text meets WCAG AA contrast in both themes. The brand orange (#F57C00) is
  used for fills with dark text; orange *text* uses a deeper shade (#A54E00).
- `test/accessibility_test.dart` checks Material's tap-target, label and
  contrast guidelines on the main screens in light and dark mode.

## Security

See [SECURITY.md](SECURITY.md) for the access model (who can read and change
what), how it's enforced and tested, and the data the app does and doesn't keep.

## Push notifications (optional)

Everything that would be pushed is also saved in the app's Notifications
screen, so the app works without Firebase. To turn on FCM push:

1. Create a Firebase project and add an Android app with the package name
   `com.thegrids.the_grids.dev` (and `com.thegrids.the_grids` for prod).
2. App: create `firebase.json` (keep it out of git) and build with
   `--dart-define-from-file=firebase.json`:
   ```json
   { "FIREBASE_API_KEY": "…", "FIREBASE_APP_ID": "1:…:android:…",
     "FIREBASE_MESSAGING_SENDER_ID": "…", "FIREBASE_PROJECT_ID": "…" }
   ```
3. API: Project settings → Service accounts → Generate new private key, save it
   outside the repo and set `FIREBASE_SERVICE_ACCOUNT_FILE` in `backend/.env`.

Without step 3 the API logs "Would push …" instead of sending. Each person
chooses what they get in Profile → Notification Preferences; "Push
notifications" off keeps updates in the app only.

## Tests

```sh
flutter analyze && flutter test        # app: 163 tests (widgets, repositories, offline cache, accessibility)
cd backend
npm run lint && npm test               # API unit tests (signatures, receipts, availability, config…)
npm run test:e2e                       # API end-to-end tests on thegrids_test (real MySQL), incl. the access matrix
```

The payment verification tests are `backend/src/payments/signatures.spec.ts`
(Razorpay HMACs, including a known-answer vector) and
`backend/test/money.e2e-spec.ts` (forged signature, tampered webhook, double
settlement, receipts).

## Configuration (`backend/.env`)

| Variable | Required | Notes |
|---|---|---|
| `DATABASE_URL`, `SHADOW_DATABASE_URL`, `TEST_DATABASE_URL` | yes | MySQL URLs (shadow and test only for development) |
| `JWT_ACCESS_SECRET`, `OTP_PEPPER` | yes | at least 32 random characters each |
| `JWT_ACCESS_TTL_SECONDS`, `REFRESH_TOKEN_TTL_DAYS` | no | 900 s and 30 days |
| `SMS_PROVIDER`, `OTP_DEV_ECHO` | no | `console` and `true` are refused in production |
| `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET` | production | empty in development = simulated gateway |
| `FIREBASE_SERVICE_ACCOUNT_FILE` | no | enables FCM push |
| `TRUST_PROXY_HOPS` | production behind a proxy | so rate limits see real client IPs |
| `UPLOADS_DIR`, `RECEIPTS_DIR` | no | local folders (move to object storage at scale) |

The API checks all of this at start-up and refuses to run with a bad or unsafe
configuration.

## Backend layout

```
backend/
  prisma/schema.prisma    full data model (money in paise)
  prisma/seed.ts          demo society: 3 towers, 30 flats, 20 owners, 4 tenants, dues, polls…
  src/auth/               OTP, tokens, guards (@Public, @Roles), SMS sender
  src/me/                 GET /v1/me
  src/societies/          GET /v1/societies (public)
  src/memberships/        POST /v1/memberships/invites (admins: anyone; owners: own tenant)
  src/home/               role-specific Home payload (stats, checklist, alert, events, weather)
  src/tower/              notices, visitors, neighbours, complaints, events
  src/facilities/         live status, slots and race-safe booking (availability.ts is pure + unit tested)
  src/payments/           orders, signature checks, webhook, receipts (gateway.ts: Razorpay or simulated)
  src/maintenance/        dues, monthly generation (daily cron), config, defaulters, reminders, society bills
  src/community/          polls (one vote per person, results after voting) and clubs + announcements
  src/notifications/      in-app notifications, preferences, FCM push (push-sender.ts), devices
  src/profile/            account (edit, preferences, delete), household, services, society, tenancy
  src/uploads/            photo uploads (content-sniffed; local disk in dev)
  src/weather/            Open-Meteo, cached 15 min per society
  src/config/env.ts       validated config; refuses dev-only settings in production
  test/                   end-to-end tests against MySQL
```

| Endpoint | Auth | Purpose |
|---|---|---|
| `GET /health` | public | API + database check |
| `GET /v1/societies?search=` | public | society picker |
| `POST /v1/auth/otp/request` | public | send a code (5 per minute per IP, 30 s cooldown, 5 per hour per number) |
| `POST /v1/auth/otp/verify` | public | code → tokens + profile (5 attempts per code) |
| `POST /v1/auth/refresh` | refresh token | rotate tokens |
| `POST /v1/auth/logout` | refresh token | revoke |
| `POST /v1/auth/switch` | bearer | act as another of your memberships |
| `GET /v1/me` | bearer | profile + memberships |
| `POST /v1/memberships/invites` | admin, owner | register a number |
| `GET /v1/home` | bearer | Home tab for the caller's role |
| `GET /v1/visitors?limit=` | bearer | own flat (residents) or whole society (admin) |
| `GET/POST /v1/notices`, `PATCH/DELETE /v1/notices/:id` | read: all · write: admin | tower-scoped notices, alerts |
| `GET /v1/neighbours` | bearer | occupied flats by tower (names only, no phone numbers) |
| `GET/POST /v1/complaints`, `PATCH /v1/complaints/:id/status` | status: admin | residents see their flat's |
| `GET /v1/events` | bearer | upcoming events |
| `GET/POST /v1/facilities`, `PATCH /v1/facilities/:id` | write: admin | live open/full/closed status |
| `GET /v1/facilities/:id/slots?date=` | bearer | bookable slots, next 7 days |
| `POST /v1/facilities/:id/bookings`, `GET /v1/bookings/mine`, `DELETE /v1/bookings/:id` | bearer | book, list, cancel |
| `POST /v1/uploads` | bearer | JPEG/PNG/WebP up to 5 MB → `/uploads/<random>.<ext>` |
| `GET /v1/dues/mine` | bearer | own flat's pending maintenance (owners) or rent (tenants) |
| `POST /v1/payments/orders` | owner, tenant | start paying a due → checkout details |
| `POST /v1/payments/verify` | bearer (payer only) | signature check → settled payment |
| `POST /v1/payments/webhook` | Razorpay signature | `payment.captured`, `order.paid`, `payment.failed` |
| `GET /v1/payments/mine`, `GET /v1/payments/:id` | bearer | own flat's payments |
| `GET /v1/payments/:id/receipt` | bearer | PDF receipt |
| `GET/PUT /v1/maintenance/config` | write: admin | line items + due day |
| `GET /v1/maintenance/summary`, `GET /v1/maintenance/defaulters` | admin | collection status |
| `POST /v1/maintenance/defaulters/:flatId/remind` | admin | notify owners (once per 24 h) |
| `POST /v1/maintenance/dues/generate` | admin | issue a month's dues now (also runs daily at 00:15) |
| `GET/POST /v1/society-bills`, `PATCH /v1/society-bills/:id/paid` | admin | the society's own bills |
| `GET /v1/polls?status=open\|closed\|all`, `GET /v1/polls/:id` | bearer | open polls first; per-option counts only after you vote, once closed, or for admins |
| `POST /v1/polls`, `POST /v1/polls/:id/close`, `DELETE /v1/polls/:id` | admin | 2–6 options; notifies every member |
| `POST /v1/polls/:id/votes` | bearer | one vote per person (unique index), even across roles |
| `GET /v1/communities`, `GET /v1/communities/:id` | bearer | clubs with member count, your membership and announcements |
| `POST /v1/communities/:id/join`, `POST /v1/communities/:id/leave` | bearer | join or leave a club |
| `GET /v1/communities/candidates`, `POST/PATCH/DELETE /v1/communities[/:id]` | admin | create/edit clubs and their member list |
| `POST /v1/communities/:id/announcements`, `PATCH/DELETE /v1/announcements/:id` | admin | club announcements; notifies the club's members |
| `PATCH /v1/me`, `DELETE /v1/me` | bearer | edit name/email/photo/language/theme; delete account (not the last admin) |
| `GET/PUT /v1/me/preferences` | bearer | notification switches and preferred payment method |
| `GET /v1/notifications`, `GET /v1/notifications/unread-count` | bearer | the bell, scoped to the current society |
| `POST /v1/notifications/:id/read`, `POST /v1/notifications/read-all` | bearer | read state |
| `PUT /v1/devices`, `DELETE /v1/devices/:token` | bearer | register this phone for push / forget it on sign-out |
| `GET/POST /v1/household`, `PATCH/DELETE /v1/household/:id` | owner, tenant | people living in the flat (no ID numbers) |
| `GET /v1/services`, `POST /v1/services`, `DELETE /v1/services/:id` | write: admin | services directory |
| `GET /v1/society` | bearer | society details and office contacts (Help) |
| `GET /v1/tenancy` | owner, tenant | owner: their tenant; tenant: owner contact and lease |
| `POST /v1/tenancy`, `PATCH /v1/tenancy/:id`, `POST /v1/tenancy/:id/end` | owner | add a tenant by mobile, edit rent terms, end the lease |

## App layout

```
lib/
  core/        config, l10n, network (Dio + auth/offline-cache interceptors),
               router + role guards, shell (nav, drawer, offline strip), theme,
               utils, shared widgets
  features/
    auth/          sign-in flow, session, token store
    home/ tower/ facilities/ maintenance/ community/ profile/ notifications/
                   each with data (repository) · domain (models) · presentation
  l10n/        app_<lang>.arb for en, hi, gu, mr, ta, te, kn, bn
assets/icon/   launcher icon sources (rendered from the logo by tool/render_app_icon_test.dart)
```

## Troubleshooting

- **API can't reach the database after a reboot**: the portable MySQL doesn't
  start on its own. Run **Tasks → MySQL: start** (or `start-mysql.cmd`).
- **App shows "Can't connect" on the emulator**: the API must be running and
  listening on `0.0.0.0:3000`; the emulator reaches it as `10.0.2.2`.
- **Build fails with odd native-asset or Gradle path errors**: Flutter and the
  Android SDK must live in paths without spaces (`C:\flutter`).
- **"Not registered"**: the number must be added for that society *and role*.
  Re-run `npm run db:seed` for the demo logins.

## Known limitations

- Notification titles and bodies are written by the server in English; the app
  itself is fully translated.
- Translations were produced for this build; have native speakers review them.
- Uploaded photos are served by unguessable URL rather than behind sign-in.
- iOS has not been built or run (needs a Mac with Xcode).

## Before launch

- Add Razorpay live keys and the webhook secret to the server, and point the
  Razorpay dashboard webhook at `https://<api>/v1/payments/webhook`.
- Set up Firebase for push (see "Push notifications" above).
- Set `TRUST_PROXY_HOPS` if the API runs behind a load balancer.
- Move `storage/receipts` and `uploads/` to object storage (S3/GCS) if the API
  runs on more than one machine.
- Replace the placeholder production API URL in `lib/core/config/app_config.dart`
  and set up release signing for the Android build.
- Plug in a real SMS provider (e.g. MSG91 with DLT-registered templates) as
  an `SmsSender`. The console sender is refused when `NODE_ENV=production`.
- Have native speakers review the 7 non-English translations.
- Swap the vector logo redraw for the designer's original SVG.
