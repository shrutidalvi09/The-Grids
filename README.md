# The Grids

*Smart Living. Smart Spaces.* A housing-society management app for India,
for admins, owners and tenants.

| Part | Stack |
|---|---|
| App (`/`) | Flutter, Riverpod 3, go_router, Dio, flutter_secure_storage |
| API (`/backend`) | Node.js, NestJS 12, Prisma 7, MySQL 8.4 |

> **Status: Phase 5 of 7.** Done so far: shell, theme, localisation (Phase 1);
> phone-OTP sign-in, sessions, role guards, demo data (Phase 2); Home and Tower
> for all roles, covering visitors, notices, neighbours, facility booking,
> complaints, events, photo uploads and weather (Phase 3); Maintenance/Rent with
> Razorpay checkout, server-side verification, PDF receipts, defaulters and
> society bills (Phase 4); Community with polls, clubs and club announcements
> (Phase 5). Profile, notifications and the drawer pages arrive in Phase 6.

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

## Tests

```sh
flutter analyze && flutter test        # app: 98 tests
cd backend
npm run lint && npm test               # API unit tests
npm run test:e2e                       # API end-to-end tests on thegrids_test (real MySQL)
```

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
  src/common/notify.ts    in-app notifications (push delivery arrives in Phase 6)
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
| `POST /v1/payments/verify` | owner, tenant | signature check → settled payment |
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

## App layout

```
lib/
  core/        config, l10n, network (Dio + auth interceptor), router + guards,
               shell (nav, drawer), theme, utils, widgets
  features/
    auth/      data (HTTP repo, token store) · domain · presentation (4 sign-in steps)
    home/ tower/ maintenance/ community/ profile/ notifications/
  l10n/        app_<lang>.arb for en, hi, gu, mr, ta, te, kn, bn
```

## Before launch

- Add Razorpay live keys and the webhook secret to the server, and point the
  Razorpay dashboard webhook at `https://<api>/v1/payments/webhook`.
- Move `storage/receipts` and `uploads/` to object storage (S3/GCS) if the API
  runs on more than one machine.

- Plug in a real SMS provider (e.g. MSG91 with DLT-registered templates) as
  an `SmsSender`. The console sender is refused when `NODE_ENV=production`.
- Have native speakers review the 7 non-English translations.
- Swap the vector logo redraw for the designer's original SVG.
