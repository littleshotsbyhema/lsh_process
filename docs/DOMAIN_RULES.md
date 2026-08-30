# Domain Rules

## Leads

Every lead should preserve both operational and emotional context.
Minimum concepts:
- identity/contact
- source
- session interest
- pregnancy/baby/child stage
- preferred date/location
- emotional memory goal
- owner
- status/temperature
- next action/follow-up

The emotional goal is first-class data, not an unstructured afterthought.

## Packages

Packages are explained by memory depth, not only price.
Do not hard-code package details into booking UI logic.
Use versioned catalogue data so historical quotes/bookings remain reconstructable.

## Quotes

An accepted quote must preserve the commercial snapshot accepted by the client.
Later catalogue changes must not alter historical accepted terms.

## Bookings

Booking confirmation must be server-controlled.
No UI action or payment event may bypass readiness requirements.
Use a lifecycle/state machine rather than a single is_booked boolean.

Suggested lifecycle concepts:
draft -> quote_pending -> quote_accepted -> payment_pending -> requirements_pending -> ready_for_confirmation -> confirmed -> preparing -> session_completed -> postproduction -> delivered -> closed

Exception states may include:
rescheduled, cancelled, refunded, on_hold.

## Privacy and Consent

Family memories are private by default.
Booking consent is not marketing consent.
No consent record means no public publishing permission.
Consent must support channel/use specificity and withdrawal history.

Privacy choices include:
- full privacy
- selective sharing
- anonymous sharing
- portfolio release
- decide later

"Decide later" is not permission.

## Safety

Safety and comfort information must be access-restricted and auditable where appropriate.
Do not bury sensitive operational information in unrestricted generic notes.

## Financial

Financial operations must be idempotent where integrations/webhooks can retry.
Refunds cannot exceed successful payments.
Manual financial corrections require permission and audit evidence.

## AI

AI explains and recommends; deterministic rules establish eligibility and critical truth.
High-impact AI actions require validated domain tools and human review where appropriate.
