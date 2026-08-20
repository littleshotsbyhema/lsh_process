# Claude Code Prompt — Repository Reconciliation

Read CLAUDE.md and every imported governing document first.

Then inspect the repository without making changes.

Produce a repository reconciliation report containing:
1. Current framework/runtime and package manager.
2. Existing app/module structure.
3. Existing Supabase migrations, functions/RPCs, RLS policies, roles/permissions, audit system, and tenant model.
4. Current implementation state for organizations, families, contacts, children, memory profiles, and leads.
5. Differences between repository reality and docs/CURRENT_MILESTONE.md.
6. Duplicate/legacy patterns that could create architecture drift.
7. The smallest safe next implementation checkpoint.
8. Exact files likely to change for that checkpoint.
9. Tests/commands that must pass before completion.

Do not edit code in this step.
Do not propose a framework migration unless the repository is currently non-functional and the migration is required to restore it.
