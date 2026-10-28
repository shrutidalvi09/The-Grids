# Security model

The Grids keeps all data behind its own API (`backend/`), so the rules a
Firebase app would put in Firestore security rules live in the API instead. They
are enforced on every request and tested as an executable table.

## Who can do what

Every request (except sign-in, the society list, health and the Razorpay
webhook) needs an access token. The token names one **membership**: a person
acting in one society with one role (Admin, Owner or Tenant).

| Rule | How it's enforced |
|---|---|
| Only active members get in | `JwtAuthGuard` re-reads the membership from the database on **every** request; a removed member or deleted account is locked out immediately, even with an unexpired token. |
| Role-restricted actions | `@Roles(...)` on each endpoint, checked by `RolesGuard` before any handler runs. Only admins write maintenance config, notices, polls, clubs, society bills, services and complaint status. |
| One society at a time | Every query is filtered by the membership's society. Ids from another society return 404, never the record. |
| Residents see only their flat | Dues, payments, receipts, visitors, complaints (for residents), household and tenancy are filtered by the membership's flat. Owners see maintenance; tenants see rent. |
| Owners manage only their own tenant | Inviting or ending a tenancy is limited to the owner's own flat. |
| One vote per person | A unique index on (poll, user), so switching roles can't add a vote. Who voted for what is never returned. |

`backend/test/access.e2e-spec.ts` lists every route with the roles allowed to
call it, checks that every other role gets 403 and that unauthenticated calls
get 401, and fails if a new route is added without a rule. The same file checks
that an admin of another society can't read or change this society's data.

## Sign-in

- Mobile number + 6-digit one-time code only. No passwords, no Aadhaar.
- Codes are stored only as HMAC hashes, expire in 5 minutes, allow 5 attempts,
  have a 30-second resend cooldown and a limit of 5 per number per hour, plus a
  per-IP limit.
- Codes are sent only to numbers registered for that society and role.
- Access tokens last 15 minutes. Refresh tokens rotate on every use and are
  stored hashed; replaying an old one revokes the whole session family.
- On the phone, the refresh token and a copy of the profile live in the
  Android Keystore / iOS Keychain.

## Payments

- The server decides the amount from the due on record; the app only says which
  due it's paying.
- Card numbers, CVV and UPI details are entered in Razorpay's checkout and
  never reach the app or the API.
- The checkout result is verified with `HMAC-SHA256(order_id|payment_id)` and
  the payment is fetched from Razorpay. Webhooks are verified with an HMAC over
  the raw body. A payment settles at most once (row lock), whichever arrives
  first.
- The simulated gateway exists only for development. Production refuses to start
  without Razorpay keys, and production app builds refuse simulated checkouts.

## Data kept on the phone

| What | Where | Cleared |
|---|---|---|
| Refresh token, last profile | Keystore / Keychain | sign-out, session expiry |
| Last API responses (offline viewing) | app-private storage, one folder per membership | sign-out, session expiry |
| Downloaded receipt PDFs | app documents folder | by the user / uninstall |

## Account deletion

Profile → Account Options → Delete my account erases name, phone, email and
photo, ends every membership, revokes sessions and push tokens, and removes
notifications and club memberships. Payment records stay (without the name) for
the society's accounts. A society's only admin must hand over first.

## API hardening

- Helmet security headers; no CORS (the API is for the mobile app only).
- Strict input validation: unknown fields are rejected.
- Uploads are limited to 5 MB, checked by file content (JPEG/PNG/WebP), and
  saved under random 128-bit names.
- Errors leave the API as `{ error: { code, message } }`; stack traces stay in
  the server log.
- Configuration is validated at start-up. Development-only settings (console
  SMS, OTP echo, simulated payments) are refused in production.
- `TRUST_PROXY_HOPS` must be set behind a load balancer so rate limits see
  client IPs.

## Known gaps

- Uploaded photos (complaints, facilities, profiles) are served by unguessable
  URL, not behind sign-in.
- SMS delivery is a console stub until a provider (e.g. MSG91 with DLT
  templates) is plugged in.
- Receipts and uploads are on local disk; use object storage with private access
  before running more than one API instance.

## Reporting a problem

Please report security issues privately to the project maintainers rather than
in a public issue.
