# Claude Code Prompt — Security and Tenant Isolation Review

Read CLAUDE.md and architecture/domain rules.
Review the current diff or target module only.

Check specifically for:
- organization_id omissions
- tenant-unsafe joins
- missing/overbroad RLS
- client-side authorization assumptions
- service-role exposure
- mutation paths that bypass controlled server/RPC behavior
- IDOR risks
- audit gaps
- destructive historical deletes
- sensitive privacy/safety data leakage
- AI/tool paths that can bypass permissions

Classify findings:
BLOCKER / HIGH / MEDIUM / LOW.

For each finding provide:
- evidence
- exploit/failure path
- smallest safe fix
- test that proves the fix

Do not make unrelated refactors.
