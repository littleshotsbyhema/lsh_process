# Claude Code Prompt — Checkpoint Verification

Read CLAUDE.md and Definition of Done.
Review all changes since the previous checkpoint.

Verify:
1. Scope matches CURRENT_MILESTONE.
2. Database invariants and migrations.
3. RLS and permissions.
4. Audit behavior.
5. Server-controlled critical transitions.
6. UI states and validation.
7. Automated test results.
8. Build/lint/typecheck.
9. Cross-tenant negative test.
10. Historical data integrity.

Return one decision:
APPROVE
APPROVE WITH MINOR CHANGES
REVISE
HOLD
REJECT

Do not approve if a security, tenant-isolation, privacy, payment, consent, or historical-integrity blocker remains.
