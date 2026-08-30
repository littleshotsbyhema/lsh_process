# Definition of Done

A module is complete only when all applicable requirements below are satisfied.

## Product
- approved lifecycle implemented
- edge cases handled
- next-action logic clear
- no contradictory business behavior

## Data
- schema is normalized appropriately
- constraints protect invariants
- migrations are reversible/safely forward-managed according to repo convention
- historical records remain reconstructable

## Security
- organization isolation verified
- RLS verified
- permissions verified
- restricted data protected
- browser has no privileged server credentials

## Mutations
- writes use approved server/RPC/domain path
- validation occurs server-side
- critical transitions cannot be bypassed in UI
- idempotency exists where retries are expected

## Audit
- sensitive/material actions produce adequate history
- actor, entity, time, action and relevant state are recoverable

## UX
- responsive behavior
- loading state
- empty state
- error state
- success feedback
- validation messages
- accessible controls and labels

## Engineering Quality
- types pass
- lint passes
- relevant unit/integration tests pass
- relevant database tests/lint pass
- build passes
- no unrelated refactor bundled into the milestone

## Verification
- primary E2E journey verified
- permission-negative path verified
- cross-tenant path verified where applicable
- production/staging verification performed when environment permits

## Documentation
- CURRENT_MILESTONE updated after approval
- important architecture decisions documented
- unresolved risks stated explicitly
