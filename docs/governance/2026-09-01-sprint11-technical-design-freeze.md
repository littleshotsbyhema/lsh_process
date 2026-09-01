# Sprint 11 Technical Design Freeze

Date: 2026-09-01 (Asia/Kolkata)
Status: PREPARED FOR FINAL FREEZE / MIGRATION FILENAME LOCK PENDING / IMPLEMENTATION HOLD

## Authority

This document translates the approved Sprint 11 functional scope into the narrow technical contract for exact Shoot Completion.

Durable authority remains:

- `docs/PRODUCT_CONSTITUTION.md`
- `docs/ARCHITECTURE.md`
- `docs/DOMAIN_RULES.md`
- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/DEFINITION_OF_DONE.md`
- `docs/governance/2026-09-01-sprint11-scope-freeze.md`

The database/server remains final authority. Browser eligibility is presentation guidance only.

Exact journey boundary:

`Stage 10 shoot_scheduled -> Stage 11 shoot_completed`

Stage 11 -> Stage 12 `selection_pending` is explicitly outside Sprint 11.

## Current canonical baseline

Production is released and closed through Stage 10 `shoot_scheduled`.

Current Production already provides:

- canonical bookings and journey-state/history relations;
- canonical Stage 10 `shoot_scheduled`, Stage 11 `shoot_completed` and Stage 12 `selection_pending` catalogue rows;
- append-only shoot schedule evidence in `booking_shoot_schedules`;
- server-controlled `mark_booking_shoot_scheduled(uuid)` for Stage 9 -> 10;
- `booking.stage.advance` granted to Founder, Studio Manager and Client Coordinator;
- `shoot.schedule` granted to Founder, Studio Manager and Client Coordinator;
- released preparation, staffing and Safety Readiness evidence through Stage 10.

Current Production does not contain:

- `shoot.complete` permission;
- `booking_shoot_completions` relation;
- `record_booking_shoot_completion(uuid,timestamptz)`;
- `mark_booking_shoot_completed(uuid)`;
- Shoot Completion UI.

The current Sprint 10 regression corpus contains a repository-wide `role_permissions` count assertion of 230. The proposed three `shoot.complete` grants therefore require a narrowly controlled compatibility update to 233 if the assertion remains in the suite.

## Selective legacy-reference rule

Historical `architecture-rebuild` evidence contains a previously designed and validated Shoot Completion implementation. It may be used only as design/reference evidence.

No legacy commit, migration timestamp, generated file, route file, or application file is authoritative merely because it existed on the legacy branch.

Any reusable behavior below has been re-evaluated against current canonical `main`/Production contracts. Wholesale cherry-pick or merge remains prohibited.

## Architectural decision 1 — explicit immutable completion evidence

Sprint 11 requires a new canonical relation:

`public.booking_shoot_completions`

Frozen minimum columns:

- `id uuid` — database generated primary key;
- `organization_id uuid NOT NULL`;
- `booking_id uuid NOT NULL`;
- `completed_at timestamptz NOT NULL` — actual operational completion time supplied to the controlled RPC;
- `recorded_at timestamptz NOT NULL DEFAULT now()` — database-controlled evidence-recording time;
- `recorded_by uuid NOT NULL` — current active organization member resolved server-side.

Required integrity:

- tenant-safe FK `(booking_id, organization_id)` -> `bookings(id, organization_id)`;
- tenant-safe FK `(recorded_by, organization_id)` -> `organization_members(id, organization_id)`;
- exactly one canonical row per `(organization_id, booking_id)`;
- `completed_at <= recorded_at`;
- historical evidence is immutable: normal UPDATE and DELETE rejected;
- no free-text notes;
- no Safety/medical fields;
- no `shoot_schedule_id`.

Rationale: completion is a material operational fact and must remain reconstructable without rewriting schedule, staffing, preparation or Safety history.

## Architectural decision 2 — narrow completion permission

Introduce exactly one permission:

`shoot.complete`

Domain:

`bookings`

Purpose:

Record immutable canonical evidence that a scheduled shoot has completed.

Initial grants are frozen exactly to:

- Founder;
- Studio Manager;
- Photographer.

No other role receives `shoot.complete` in Sprint 11.

This permission is deliberately separate from `booking.stage.advance`.

Separation of duties is intentional:

- Photographer may record completion evidence but does not gain journey-advance authority;
- Client Coordinator may advance a valid completed booking because they already hold `booking.stage.advance`, but does not gain completion-recording authority;
- Founder and Studio Manager may perform both where all server-side conditions are satisfied.

No direct role-name check is permitted inside the controlled operations; authorization remains capability-based.

## Architectural decision 3 — completion recording RPC

Introduce exactly one recording operation:

`public.record_booking_shoot_completion(p_booking_id uuid, p_completed_at timestamptz)`

Return:

`public.booking_shoot_completions`

Required properties:

- `SECURITY DEFINER`;
- `SET search_path = ''`;
- explicit execute ACL;
- callable by `authenticated` only as the application mutation surface;
- `PUBLIC` denied;
- `anon` denied;
- `service_role` denied as the application mutation surface.

First-success authorization and validation:

1. non-null booking id;
2. non-null completion timestamp;
3. authenticated `auth.uid()`;
4. existing booking;
5. active organization membership;
6. `shoot.complete` for the booking branch;
7. canonical branch scope where a branch exists;
8. exactly one current journey-state row;
9. exact current Stage 10 / `shoot_scheduled`;
10. current authoritative shoot-schedule tip exists and is `reserved`;
11. `p_completed_at <= database now()`.

The caller must not supply:

- organization id;
- branch id;
- actor/member id;
- destination stage;
- journey version;
- schedule id/state/version;
- staffing state;
- Safety state;
- notes or narrative text.

Exact replay semantics:

- same booking + exactly equal `completed_at`: return the existing immutable completion row;
- no duplicate completion row;
- no duplicate audit event.

Conflict semantics:

- same booking + different `completed_at`: reject;
- original evidence remains unchanged.

No grace window, minimum shoot duration, scheduled-end comparison, auto-completion timer or other invented time heuristic is authorized.

## Architectural decision 4 — completion audit

First successful recording appends exactly one structural audit event:

`booking.shoot_completion_recorded`

Audit must preserve:

- organization;
- booking entity id;
- current member actor;
- branch scope where applicable;
- completion id;
- completion timestamp.

Audit must not contain:

- Safety/comfort values;
- medical information;
- family/private notes;
- incident narratives;
- external-creative personal details;
- arbitrary unrestricted user text.

Exact idempotent replay adds no audit event.

## Architectural decision 5 — completion terminalizes future schedule evidence

Current `booking_shoot_schedules` history is append-only and permits reserved -> reserved rescheduling while a booking remains Stage 10.

Completion evidence is intentionally booking-level and does not bind to a schedule-row id. Therefore Sprint 11 must prevent a new authoritative schedule version from being appended after canonical completion evidence exists.

The Stage 10 -> 11 migration must harden the existing internal:

`public.lsh_booking_shoot_schedule_guard()`

Frozen rule:

Once `booking_shoot_completions` contains a row for `(organization_id, booking_id)`, any new `booking_shoot_schedules` INSERT for that booking is rejected.

This rule does not:

- rewrite historical schedule rows;
- delete history;
- change schedule version numbering;
- change proposed/reserved vocabulary;
- add `shoot_schedule_id` to completion evidence;
- infer schedule identity from timestamps;
- prohibit pre-completion Stage 10 rescheduling;
- convert exact replay that performs no INSERT into an error.

## Architectural decision 6 — exact Stage 10 -> 11 RPC

Introduce exactly one advancement operation:

`public.mark_booking_shoot_completed(p_booking_id uuid)`

Return:

`public.bookings`

Required properties:

- `LANGUAGE plpgsql`;
- `SECURITY DEFINER`;
- `SET search_path = ''`;
- `PUBLIC` denied;
- `anon` denied;
- `service_role` denied as the application mutation surface;
- explicit execute grant to `authenticated`.

No new permission is introduced by this second operation.

First-success authorization:

1. non-null booking id;
2. authenticated actor;
3. existing booking;
4. active organization membership;
5. existing `booking.stage.advance` for the booking branch;
6. branch scope where applicable.

It must not require:

- `shoot.complete`;
- same actor as `recorded_by`;
- Photographer role;
- Client Coordinator role;
- a direct role-name test.

## Synchronization and concurrency contract

The booking row remains the synchronization root shared with existing booking/schedule operations.

Required first-success lock order:

1. `bookings` target row — `FOR UPDATE`;
2. exactly one `booking_journey_states` row — `FOR UPDATE`;
3. exactly one `booking_shoot_completions` row — `FOR UPDATE`;
4. current authoritative `booking_shoot_schedules` tip — `FOR UPDATE`.

This ordering must be consistent with current booking/schedule mutation discipline and must prevent concurrent schedule/completion/advancement races from producing contradictory history.

## Stage-state contract

First advancement is legal only when current active stage is exactly:

- `stage_order = 10`;
- `stage_key = 'shoot_scheduled'`.

Destination must be resolved explicitly as the active catalogue row:

- `stage_order = 11`;
- `stage_key = 'shoot_completed'`.

No generic next-stage calculation is authorized.

Exactly one canonical completion row must exist before advancement.

The current authoritative schedule tip must still be `reserved`.

The operation does not rerun or reinterpret Stage 9 readiness evidence.

## Explicit non-revalidation boundary

Stage 10 proves that the prior pre-shoot readiness gate was already satisfied. Sprint 11 must not re-run:

- preparation taxonomy;
- checklist satisfaction;
- staffing eligibility;
- Lead Photographer assignment eligibility;
- Stylist eligibility;
- Videographer commercial requirements;
- Safety Readiness;
- Newborn formal sign-off;
- package/service-category readiness semantics.

Shoot Completion consumes canonical Stage 10 state, immutable completion evidence and current reserved schedule integrity only.

## Journey transition contract

First success inserts exactly one `booking_stage_transitions` row:

- organization: booking organization;
- booking: target booking;
- from stage: exact Stage 10 `shoot_scheduled`;
- to stage: exact Stage 11 `shoot_completed`;
- `transition_key = 'shoot_completed'`;
- `transitioned_at`: one function-controlled timestamp;
- `transitioned_by`: current active organization member.

Then update the one canonical journey state:

- `current_stage_id` -> exact Stage 11;
- `stage_entered_at` -> the same transition timestamp;
- `version` -> prior version + 1;
- `updated_by` -> advancing actor.

The update must use optimistic identity/version predicates against the state loaded under lock and must verify exactly one row changed.

No booking shell identity/commercial field is rewritten.

## Stage 11 replay contract

If a booking is already exact Stage 11 / `shoot_completed`, `mark_booking_shoot_completed(uuid)` succeeds only as strict canonical replay.

Replay must prove:

- exactly one completion row exists;
- exactly one Stage 10 -> 11 transition exists;
- transition key is `shoot_completed`;
- source is exact Stage 10 `shoot_scheduled`;
- destination is exact Stage 11 `shoot_completed`.

Valid replay:

- returns the booking;
- adds no transition;
- updates no journey state;
- adds no audit event.

Missing, duplicated or malformed replay history rejects.

## Advancement audit contract

First successful Stage 10 -> 11 advancement appends exactly one structural audit event:

`booking.shoot_completed`

Permitted structural context:

- booking id;
- completion id;
- completion timestamp;
- transition key;
- prior journey version;
- resulting journey version.

Sensitive/free-text data is prohibited.

Valid replay adds no duplicate audit event.

## Safe authenticated read model

No additional per-booking RPC is required merely to render completion evidence.

Preferred read path:

- `booking_shoot_completions` grants authenticated SELECT only;
- RLS + FORCE RLS;
- SELECT policy requires canonical `booking.read` and booking-derived branch scope;
- authenticated direct INSERT/UPDATE/DELETE remains denied;
- `anon` receives no table access;
- browser/server workspace fetches all visible completion rows for the current booking set in one batched query.

This decision deliberately avoids increasing the known Bookings per-booking RPC fan-out debt.

The read surface contains only structural completion evidence and no Safety/private narrative data.

## Bookings application contract

Application integration is limited to the existing authenticated Bookings workspace.

Server module additions in `src/lib/booking.functions.ts`:

- `BookingShootCompletionRow` generated-table type alias;
- completion evidence in `BookingWorkspaceData`;
- per-booking `canRecordShootCompletion` capability derived from `shoot.complete`;
- batched completion read through canonical RLS;
- validated wrapper for `record_booking_shoot_completion(uuid,timestamptz)`;
- validated wrapper for `mark_booking_shoot_completed(uuid)`.

UI additions in `src/routes/_authenticated/bookings.tsx`:

- exact Stage 10 completion evidence panel;
- completed-at datetime input for actors with presentation-level `canRecordShootCompletion` and no existing completion row;
- mutation success/error/loading feedback;
- workspace refetch after recording;
- after completion evidence exists, render immutable completed-at/recorded-at provenance;
- Stage 10 -> 11 advancement control only when completion evidence exists and the actor has presentation-level `canAdvanceBookingStage`;
- workspace refetch after advancement;
- at Stage 11, completion evidence remains historical/read-only;
- no record/replay button after evidence exists;
- no repeated Stage-11 advancement button;
- no Stage 12 action.

The browser must not reproduce authoritative schedule, membership, branch, journey, completion-cardinality or replay-history validation. The RPCs revalidate all critical truth.

## UI language and brand behavior

The operational UI should communicate completion as a careful evidence checkpoint, not a generic status toggle.

Recommended concise labels:

- `Record shoot completion`
- `Shoot completion evidence`
- `Mark shoot completed`

The UI must distinguish:

- recording that the session actually completed; and
- advancing the operational journey after that evidence exists.

This supports care, trust and reconstructable memory-preservation operations rather than reducing the event to an unchecked CRM status change.

## Migration filename lock protocol

The technical contracts and logical migration names are frozen as:

1. `sprint11_shoot_completion_evidence_foundation`
2. `sprint11_stage10_11_gate_foundation`

Exact timestamped filenames are intentionally not invented in this governance-only checkpoint.

Before implementation SQL is written:

1. integrate the approved Sprint 10 reconciliation + Sprint 11 governance into current `main` through explicit review;
2. create a short-lived Sprint 11 implementation branch from that exact `main` head;
3. run the installed Supabase CLI help/version checks;
4. create each migration file using `npx supabase migration new <logical_name>`;
5. record the exact generated filenames in this document or an explicit freeze amendment;
6. only then may SQL implementation begin after explicit implementation authorization.

This protocol prevents invented migration timestamps and prevents implementation on the governance branch.

## Frozen implementation file boundary after filename lock

Expected implementation boundary is exactly eight paths, with two migration filenames pending CLI generation:

1. `supabase/migrations/<generated>_sprint11_shoot_completion_evidence_foundation.sql`
2. `supabase/tests/sprint11_shoot_completion_evidence_test.sql`
3. `supabase/migrations/<generated>_sprint11_stage10_11_gate_foundation.sql`
4. `supabase/tests/sprint11_stage10_11_gate_test.sql`
5. `src/integrations/supabase/types.ts`
6. `supabase/tests/sprint10_extended_creative_assignments_test.sql` — only the repository-wide role-permission count/message compatibility assertion required by the three intentional `shoot.complete` grants;
7. `src/lib/booking.functions.ts`
8. `src/routes/_authenticated/bookings.tsx`

No fourth database/application surface and no ninth file is permitted without a governance amendment before modification.

`src/routeTree.gen.ts` is not an authorized semantic change. If normal tooling regenerates it without a route change, classify and restore it before commit.

## Generated type contract

After both migrations apply cleanly and dedicated database tests are green, regenerate Supabase application types from the canonical local database.

Expected new generated surface is limited to:

- table `booking_shoot_completions`;
- function `record_booking_shoot_completion`;
- function `mark_booking_shoot_completed`;
- permission enum/catalogue data does not create an unrelated TypeScript structural expansion.

Do not copy legacy generated types.

## Dedicated pgTAP — completion evidence suite

Add:

`supabase/tests/sprint11_shoot_completion_evidence_test.sql`

Minimum acceptance matrix:

A. exactly one `shoot.complete` permission exists and requires server enforcement;
B. grants are exactly Founder, Studio Manager and Photographer;
C. completion table exposes the frozen six-column evidence model;
D. tenant-safe booking and recorder FKs exist;
E. one-row-per-booking uniqueness exists;
F. `completed_at <= recorded_at` protected by constraint;
G. RLS enabled and forced;
H. authenticated SELECT follows `booking.read` + branch scope;
I. authenticated direct INSERT/UPDATE/DELETE denied;
J. anon table access denied;
K. recording RPC exact signature/result/security-definer/empty-search-path contract;
L. authenticated EXECUTE available; PUBLIC/anon/service-role application execution denied;
M. unauthenticated invocation rejected;
N. inactive/non-member rejected;
O. actor without `shoot.complete` rejected;
P. cross-branch invocation rejected;
Q. wrong-stage invocation rejected;
R. exact Stage 10 accepted when schedule/evidence constraints pass;
S. missing/non-reserved authoritative schedule rejected;
T. future `completed_at` rejected;
U. successful insert attributes `recorded_by` to current member;
V. exact replay returns same row and creates no duplicate evidence;
W. conflicting replay rejected;
X. UPDATE rejected;
Y. DELETE rejected;
Z. first success emits exactly one `booking.shoot_completion_recorded` audit;
AA. replay does not duplicate audit;
AB. recording alone leaves journey at Stage 10 and inserts no Stage 10 -> 11 transition;
AC. tenant isolation remains intact.

## Dedicated pgTAP — Stage 10 -> 11 suite

Add:

`supabase/tests/sprint11_stage10_11_gate_test.sql`

Minimum acceptance matrix:

A. `mark_booking_shoot_completed(uuid)` exists with exact signature/result;
B. no additional permission introduced by gate migration;
C. no role grant changed by gate migration;
D. authenticated EXECUTE exists; PUBLIC/anon/service-role application EXECUTE denied;
E. SECURITY DEFINER + empty search path;
F. null booking rejected;
G. unauthenticated rejected;
H. missing booking rejected;
I. inactive/non-member rejected;
J. actor without `booking.stage.advance` rejected;
K. branch-scope violation rejected;
L. malformed current journey-state cardinality rejected;
M. Stage 9 first call rejected;
N. Stage 12/later first call rejected;
O. Stage 10 without completion evidence rejected;
P. Stage 10 without a current reserved schedule rejected;
Q. Photographer can record evidence but cannot advance solely from `shoot.complete`;
R. Client Coordinator can advance valid evidence without `shoot.complete`;
S. Founder valid advancement succeeds;
T. Studio Manager valid advancement succeeds;
U. success resolves exact Stage 11 `shoot_completed`;
V. exactly one `shoot_completed` transition appended;
W. transition source/destination identities exact;
X. journey version increments exactly once;
Y. `stage_entered_at` equals transition timestamp;
Z. actor attribution exact;
AA. exactly one `booking.shoot_completed` audit appended;
AB. audit contains structural, non-sensitive context only;
AC. completion evidence remains unchanged;
AD. schedule history remains unchanged;
AE. no Stage 11 -> 12 transition created;
AF. valid Stage 11 replay succeeds without transition/state/audit write;
AG. replay with missing/malformed transition history rejects;
AH. replay with missing completion rejects where structurally reproducible;
AI. post-completion new schedule INSERT rejected;
AJ. pre-completion Stage 10 rescheduling remains legal;
AK. existing schedule history is not rewritten by terminality;
AL. no timestamp schedule-binding inference introduced;
AM. no `shoot_schedule_id` appears on completion evidence;
AN. no Stage 12/selection surface introduced.

## Regression compatibility boundary

Adding `shoot.complete` with three initial grants changes the canonical repository-wide `role_permissions` total from 230 to 233.

The only pre-authorized compatibility change to `supabase/tests/sprint10_extended_creative_assignments_test.sql` is:

- expected total `230` -> `233`;
- assertion wording updated to describe the current repository-wide total rather than the old Slice 6A snapshot.

No test plan, fixture, role entitlement or other Sprint 10 behavior may change under this compatibility allowance.

If any other historical test fails, STOP and create a separate boundary amendment before modifying that test.

## Application/E2E acceptance

Controlled local E2E must prove at minimum:

1. exact Stage 10 booking with reserved schedule and valid released pre-shoot history;
2. Photographer sees completion-recording action but no journey-advance action;
3. Photographer records an actual completion time successfully;
4. completion evidence renders immutable and remains Stage 10;
5. new schedule/reschedule INSERT after completion is rejected server-side;
6. Client Coordinator cannot record completion but can advance already-recorded valid completion;
7. Founder and Studio Manager can perform both capabilities where appropriate;
8. authorized advancement creates exact Stage 10 -> 11 history;
9. Stage 11 renders completion evidence read-only;
10. Stage 11 offers no completion replay control;
11. Stage 11 offers no Stage 12 action;
12. permission-negative and branch-negative calls reject server-side;
13. no Safety/private narrative appears in completion evidence or audit;
14. relevant existing booking/scheduling/preparation/team/Safety behavior remains intact.

The E2E journey must stop at exact Stage 11.

## Full implementation verification profile

Before implementation can be accepted:

- exact implementation-base guard;
- exact file-boundary guard;
- fresh `npx supabase db reset --local`;
- dedicated completion-evidence pgTAP PASS;
- dedicated Stage 10 -> 11 pgTAP PASS;
- complete local pgTAP regression PASS;
- `npx supabase db lint --local` PASS;
- `npx supabase db advisors --local` reviewed;
- regenerate local Supabase types;
- generated-type semantic diff reviewed;
- targeted Prettier PASS;
- targeted ESLint for changed application files PASS;
- `npx tsc --noEmit` PASS;
- `npm run build` PASS;
- `git diff --check` PASS;
- explicit RLS/ACL/function-security inspection;
- exact permission/grant matrix inspection;
- no unexpected route-tree semantic change;
- explicit forbidden-surface scan for Stage 11 -> 12/selection/editing/QC/gallery/delivery;
- controlled local E2E reaches and stops at Stage 11;
- Preview deployment/review only after implementation commit/push is separately authorized;
- no Production migration/deployment without separate explicit approval.

## Production release containment

Sprint 11 implementation authorization does not authorize Production.

Before any Production database write, require a separate release gate including:

- frozen exact migration manifest;
- Production migration-ledger preflight;
- linked CLI dry-run showing only the authorized Sprint 11 migrations;
- explicit Production deployment approval;
- post-migration ledger/RLS/ACL/RPC verification;
- non-destructive Production application smoke;
- no synthetic client booking merely for testing unless separately authorized.

## Explicit exclusions

Sprint 11 Technical Design does not authorize:

- Stage 11 -> Stage 12 `selection_pending`;
- client selection/proofing;
- editing/retouching;
- QC;
- Pixieset/gallery publication;
- delivery;
- album/frame production;
- review/milestone follow-up;
- media custody/dual custody;
- shoot-day Safety incident records;
- post-session Safety/medical notes;
- free-text completion notes;
- automatic completion from elapsed time;
- new schedule/completion timestamp heuristics;
- generic journey mutation;
- unrelated Team/RBAC/CRM/package/quotation/payment changes;
- public website work;
- wholesale legacy branch migration;
- Production mutation/deployment without separate explicit approval.

## Final-freeze gate

The technical architecture, data model, permissions, RPC contracts, replay semantics, UI boundary, test matrices and logical implementation boundary are PREPARED and approved for review by this document.

This is not yet the final implementation authorization because two repository-control prerequisites remain:

1. integrate the completed reconciliation/scope governance into canonical `main`;
2. create the two timestamped migration files on a new Sprint 11 branch using `npx supabase migration new ...`, then record those exact generated filenames in a freeze amendment.

Until those prerequisites are completed:

- implementation remains HOLD;
- no Sprint 11 SQL/application code should be written;
- no Production action is authorized.

Decision state:

**SPRINT 11 TECHNICAL DESIGN PREPARED / FINAL FILENAME LOCK PENDING / IMPLEMENTATION HOLD / PRODUCTION NOT AUTHORIZED**
