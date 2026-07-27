## Little Moments OS — V3

Confirmed current state: all data lives in an in-memory Zustand store seeded from `src/lib/mock-data.ts` (no persistence layer, no backend, no auth). The SOP Center page exists at `/sops` but has no sidebar link. Work is phased so the app stays usable throughout.

---

### Phase A — Make the studio's data real (Lovable Cloud)

Turn on Lovable Cloud (database + logins + server code, no external accounts).

Tables mirroring today's store: leads, clients, memory_profiles, bookings, quotes, privacy_consents, safety_checklists, shoot_prep, editing_jobs, pixieset_galleries, heirloom_jobs, follow_ups, tasks, reviews, governance_reviews, team_members, settings. Each gets access grants + row-level security so only signed-in studio staff can read/write.

Seeded with the current demo records so the app looks identical on first load, then keeps everything after refresh.

The Zustand store stays as the app's state layer — its actions (and all existing guards) start reading/writing the database instead of memory, so no page has to be rewritten.

### Phase B — Logins and role-based access

- Email + password sign-in, plus Google sign-in.
- A separate `user_roles` table (never a column on the profile) holding the 9 roles: Founder/Admin, Studio Manager, Client Coordinator, Photographer, Assistant, Editor, Album Coordinator, Marketing Team, Accounts.
- Founder/Admin invites team members and assigns roles from the existing Team page.
- Sidebar shows only the modules a role owns; My Tasks shows only that person's tasks. Access is enforced on the server too, not just hidden in the UI.
- Warm, on-brand sign-in screen with the philosophy line.

### Phase C — Polish and gap fixes

- Add SOP Center to the sidebar (currently unreachable).
- Mobile navigation: a slide-out drawer for the 20+ nav items on small screens.
- Per-page metadata: unique title, description and social-preview tags on every route.
- Global search across leads, clients and bookings.
- Consistent empty states and a signed-in-user footer that reflects the real account.

### Phase D — Client-facing pages

Public, link-shareable pages (no login) tied to a booking token:

- **Proposal** — recommended package, inclusions, price, accept button.
- **Consent form** — privacy/marketing consent captured and signed by the family, feeding straight into the Privacy module.
- **Delivery page** — gallery link, password, album/frame status, and a gentle review request.

Each is warm, minimal, and philosophy-led; submissions land back in the internal modules and trigger the existing task automations.

---

### Technical notes

- Backend: Lovable Cloud (Postgres + auth + server functions). Data access via `createServerFn`; protected pages under an authenticated route group.
- Roles checked through a security-definer `has_role()` function used inside RLS policies, avoiding recursive policy issues.
- Client-facing pages live under public routes with a random per-booking token and narrowly scoped read policies — no studio data exposed beyond that booking.
- Existing guards (safety → Shoot Completed, consent → marketing, selection+payment → editing, selections → heirloom) move into server-side checks so they can't be bypassed.
- All KPI computation stays live, now over database rows.

Suggested order: A → B → C → D. Phase A is the largest single step; I'd do it first so nothing built afterwards has to be redone.
