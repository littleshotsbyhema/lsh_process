## Little Moments OS — V3 Hardening

Four workstreams, in this order. Verified current state first:

- All 14 studio collections already sync to the backend as JSON documents (leads, bookings, clients hold live rows), so persistence exists but is **write-behind and unverified** — no save feedback, no conflict handling, no multi-device refresh.
- Access rules today are **cosmetic**: the sidebar hides pages a role shouldn't see, but typing the URL still opens any module. Database rules only check "is this person studio staff", not which role.
- Family-facing links (proposal / consent / delivery) and their responses are built, but no link or response has ever been created — the flow is untested end to end.
- Only one account has a role (the Founder).

---

### 1. Finish persistence

- Replace the silent background sync with an explicit save state: a small "Saving… / All changes saved / Couldn't save" indicator in the header, and a retry when a write fails.
- Fix the first-run seeding rule so starter demo records are only ever written once for the studio, never re-pushed after a team member deletes something.
- Persist the modules that currently live only in memory: auto-generated team tasks, quote drafts, and settings/studio preferences.
- Refresh-on-focus so a second person's changes appear without a reload.
- Verify by writing in one browser session and reading back in a second.

### 2. Role-based access (real enforcement)

- Add a shared role guard so every module checks the signed-in person's roles on entry; unauthorised URLs land on a warm "This room isn't yours to open" page instead of the module.
- Split action permissions from view permissions: e.g. Editors can move editing status but not change money fields; Accounts can see payments but not edit safety checklists; only Founder/Coordinator can advance pipeline stages past Booking Confirmed; only Founder manages the team.
- Tighten backend rules from "any staff" to role-aware for the sensitive tables (privacy/consent, marketing approval, financial fields on bookings, governance scores) via a migration using the existing role function.
- Add a "Your access" panel on Settings showing exactly what the current person can and can't do.

### 3. Client-facing views

- Test and finish the three family link types: proposal (accept / request changes), consent (explicit marketing permission with signature name and date), delivery (gallery link, password, album status).
- Feed responses back into the studio: an accepted proposal advances the booking stage, a signed consent writes the Privacy record and unlocks Marketing Approvals, and a delivery view logs "family opened gallery".
- Add link management to every relevant module (not just Bookings): copy link, see status, revoke, regenerate, expiry.
- Give family pages the studio's brand treatment on mobile first, plus a thank-you state after submitting.

### 4. Bug sweep & UX polish

- Walk all 22 modules for: empty states, mobile layout at 393px, broken guard messages, dead buttons, and stale mock data still showing as if real.
- Make every guard failure explain the exact missing step and link to it (e.g. "Safety checklist pending — open Safety & Comfort").
- Consistent page header, footer line, loading and error states across modules.
- Confirm dashboard and KPI counts match the database after the persistence fixes.

---

### Technical notes

- Guard: a shared `requireRoles` helper used by each route's `beforeLoad` under `_authenticated`, reading roles from route context (loaded once in the layout) rather than per-page hooks, to avoid content flashing.
- Role-aware backend rules: new migration adding `has_any_role(...)` checks to policies on `privacy_records`, `bookings`, `governance_runs`, `alignment_scores`; keep `is_staff` for read-only tables.
- Sync: move save/flush into a small queue with status published to the store; keep the existing `{ id, data }` JSON document shape (no schema rewrite).
- Client links: extend `submitClientResponse` to apply the effect server-side (privacy record, stage advance) inside the same server function, so families never need an account.
