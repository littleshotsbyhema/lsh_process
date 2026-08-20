# Claude Code Prompt — Implement Current Checkpoint

Read CLAUDE.md and all imported docs.
Read the latest repository reconciliation/checkpoint notes.

Implement only the smallest approved checkpoint in docs/CURRENT_MILESTONE.md.

Before editing:
- identify lifecycle/state transitions
- identify database invariants
- identify permissions/RLS impact
- identify audit requirements
- identify all existing patterns to reuse

During implementation:
- database/security before UI where required
- preserve historical integrity
- use controlled server/RPC mutations
- do not expose privileged credentials
- do not add speculative abstractions

Verification:
- run relevant database reset/lint/tests
- run typecheck/lint/tests/build
- verify primary happy path
- verify permission failure path
- verify cross-tenant isolation where applicable

Finish with a checkpoint report:
- summary
- files changed
- migrations/functions/policies changed
- tests and results
- manual verification
- unresolved risks
- whether Definition of Done is satisfied
- exact next dependency
