# The Grids – Add-on ideas

Features that could be added next, grouped by area. Each has a rough size:
**S** = a few days, **M** = 1–2 weeks, **L** = 3+ weeks (app + API + tests).

"Builds on" names what already exists in the code, so the work is smaller.

---

## 1. Finish what's half-built (do these first)

These have a database model or an API endpoint already, but no way to use them in the app yet.

| Add-on | What it does | Size | Builds on |
|---|---|---|---|
| **Invite residents (admin screen)** | Admin adds an owner/tenant/admin by mobile number and picks the flat. Today this only exists as an API call. | S | `POST /v1/memberships/invites` |
| **Pre-approve visitors** | Resident adds an expected guest, maid or delivery from the app, and it appears in the gate log. Today visitors can only be viewed. | M | `Visitor` model, Visitors page |
| **Create and edit events (admin)** | Events are shown on Home but can only be added through the seed data. | S | `Event` model, Events page |
| **Rate service providers** | Residents give 1–5 stars to the maid, plumber and so on; the average shows in the directory. | S | `rating` field on `ServiceProvider` |
| **Translate server notifications** | Push and in-app notification text is English only; send it in each user's language. | S | `User.language`, NotificationsService |

## 2. Security and gate

| Add-on | What it does | Size | Notes |
|---|---|---|---|
| **Guard / security app (4th role)** | A simple app for the gate: check visitors in and out, take a photo, call the flat. | L | New `GUARD` role; reuses the Visitor model |
| **Guest pass (QR / code)** | Resident shares a one-time code or QR with a guest; the guard scans it at the gate. | M | Needs the guard app |
| **Approve at the gate** | Unexpected visitor → push to the flat: "Allow / Deny" in one tap. | M | Push notifications already wired |
| **Daily help attendance** | Maid, cook and driver check-in history per flat; monthly attendance report. | M | Checklist on Home already shows check-ins |
| **SOS / panic button** | One tap alerts the guards, admins and household members, with the flat number. | S | Notifications + "alert" type exist |
| **Vehicles and parking** | Register vehicles per flat, assign parking slots, guest parking requests. | M | |

## 3. Money and accounts

| Add-on | What it does | Size | Notes |
|---|---|---|---|
| **UPI AutoPay** | Residents set up a mandate once; maintenance is collected automatically each month. | M | Razorpay Subscriptions / e-mandates |
| **Late fees** | Automatic penalty after the due date (fixed or %), shown in the breakdown. | S | Daily dues job already runs |
| **Advance and partial payments** | Pay several months at once, or part of a due; credit balance per flat. | M | |
| **Society ledger and reports** | Income vs expenses, month-end report, export to Excel/PDF or Tally. | L | Payments + Society Bills data exist |
| **GST invoices** | GST-compliant invoices for societies that are registered for GST. | M | Receipt PDF generator exists |
| **Refunds** | Admin refunds a double payment from the app (the API already flags these in the log). | S | Razorpay refunds API |
| **Sinking / repair fund tracking** | Separate funds with their own balance and history. | M | |

## 4. Communication

| Add-on | What it does | Size | Notes |
|---|---|---|---|
| **WhatsApp messages** | Dues reminders, receipts and notices on WhatsApp (very common in Indian societies). | M | Meta WhatsApp Business API + template approval |
| **Discussion forum / chat** | Society-wide or club threads with replies and photos. | L | Clubs and announcements exist |
| **Document library** | Bylaws, AGM minutes, NOCs and circulars, with download. | S | Upload + storage exist |
| **Notice read receipts** | See how many residents have read an important notice. | S | Notification read state exists |
| **Meetings and AGM** | Schedule meetings, attendance, agenda, minutes, formal e-voting with quorum. | L | Polls exist (one vote per person) |

## 5. Facilities and complaints

| Add-on | What it does | Size | Notes |
|---|---|---|---|
| **Paid bookings** | Charge for the clubhouse or party hall through Razorpay, with a refundable deposit. | M | Booking + payments both exist |
| **Waitlist and recurring bookings** | "Every Tuesday 7 AM", or join the queue for a full slot. | M | Race-safe booking already in place |
| **Assign complaints to staff** | Admin assigns to an electrician or plumber; staff update the status from their phone. | M | Complaint status flow exists |
| **Complaint SLA and rating** | Target resolution time, overdue alerts, and the resident rates the fix. | S | |
| **Before/after photos** | Staff attach a photo when they resolve a complaint. | S | Photo upload exists |

## 6. Society management (admin)

| Add-on | What it does | Size | Notes |
|---|---|---|---|
| **Web admin dashboard** | Desktop screens for the committee: bulk edits, reports, exports. | L | Same API; e.g. Flutter web or React |
| **Bulk import residents** | Upload a CSV/Excel of flats, owners and phone numbers. | S | Invite endpoint exists |
| **Committee roles** | Secretary, treasurer and chairman with different permissions (e.g. only the treasurer sees accounts). | M | Role guard system exists |
| **Staff and payroll** | Guards, housekeeping and gardeners: attendance, salary, payslips. | L | |
| **Vendor AMC tracker** | Lift, fire safety, water tank and pest control contracts, with renewal reminders. | S | Society Bills exist |
| **Move-in / move-out** | Request, admin approval, lift booking, and dues clearance before move-out. | M | Tenancy flow exists |
| **Audit log** | Who changed what and when (config, bills, member list). | S | |
| **Multi-society console** | For property-management companies that run many societies. | L | The data is already per society |

## 7. Resident community

| Add-on | What it does | Size |
|---|---|---|
| **Marketplace / classifieds** | Buy, sell or give away within the society. | M |
| **Car pooling** | Find neighbours going the same way. | M |
| **Lost and found** | Post a photo of something lost or found. | S |
| **Pet registry** | Pets per flat, vaccination dates. | S |
| **Rent / sell a flat** | Owners list a flat for rent or sale inside the society. | M |
| **Utility meter readings** | Water and electricity sub-meter readings, billed with maintenance. | M |

## 8. Platform, quality and launch

| Add-on | What it does | Size | Notes |
|---|---|---|---|
| **Real SMS for login codes** | Replace the console sender. | S | MSG91 / Twilio with DLT-registered templates (needed in India) |
| **iOS app** | Build, sign and test on iPhone. | M | Needs a Mac with Xcode |
| **Play Store release** | Release signing, store listing, privacy policy, data-safety form. | S | |
| **Crash reporting and analytics** | Firebase Crashlytics or Sentry; anonymous usage stats. | S | Firebase already in the app |
| **App lock** | Fingerprint/face unlock when the app opens. | S | `local_auth` package |
| **Deep links** | Links in WhatsApp/SMS open the right screen (receipt, notice, poll). | S | Notification routing already exists |
| **Cloud storage for files** | Move receipts and photos to S3/GCS with private access. | S | Listed in SECURITY.md |
| **CI pipeline** | Run all tests automatically on every push (GitHub Actions). | S | 167 app + 254 API tests already exist |
| **DPDP Act compliance** | India's Digital Personal Data Protection Act 2023: consent screen, data export, grievance contact. | M | Account deletion already exists |
| **Home screen widget** | Shows the dues amount and today's visitors without opening the app. | M | |

---

## Suggested order

1. **Invite residents screen**: without it, an admin can't add people from the app.
2. **Pre-approve visitors** and **Approve at the gate**: the feature residents use every day.
3. **Real SMS + Play Store release**: needed to go live.
4. **UPI AutoPay** and **WhatsApp reminders**: fewer defaulters and less chasing for the admin.
5. **Guard app**: makes the gate features complete.
6. **Society ledger and reports**: what the treasurer will ask for next.
