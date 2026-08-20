# Claude Code Prompt — Pre-Push Verification

MODE: Auto

Read CLAUDE.md and the current CURRENT_MILESTONE.md checkpoint first.

Require these exact inputs before starting:

- expected branch
- expected local HEAD (full SHA)
- expected origin HEAD (full SHA, i.e. origin's state before this push)
- commits expected above origin
- exact expected commit/file boundaries for each commit in range
- exact expected complete push delta (file list)
- production status

Then inspect the repository without making changes.

Verify, in order:

1. Branch matches the expected branch.
2. Working tree is clean (or matches the expected state if not).
3. Local HEAD matches the expected SHA.
4. Origin HEAD matches the expected pre-push SHA.
5. Commits above origin match the expected commit list exactly.
6. Each commit's changed-file boundary matches its governed authorization
   exactly (no unexpected file, no missing file).
7. The complete push delta (diffed against origin) matches the expected
   file list exactly — no unexpected migration, pgTAP, generated-type, or
   routeTree file.
8. `git diff --check` is clean across the full range.
9. Implementation-commit and checkpoint-commit contracts are internally
   consistent (e.g. a checkpoint doc's claims match what the implementation
   commit actually contains).
10. Secret/fixture hygiene: sweep the full delta for email, UUID-shaped
    token, password/secret/key/token/credential keyword, `/tmp/` path,
    localhost/local-Supabase-port URL, and admin/credential-marker
    patterns. Report only category, count, and filename — never print a
    matched value or line.
11. Production status is explicitly HOLD unless a separately governed
    release procedure states otherwise.
12. Final re-check: repeat the branch/working-tree/HEAD/origin check once
    more immediately before reporting, to catch any change introduced
    during the verification itself.

`scripts/verify-checkpoint.sh pre-push --branch <name> --expect-head <sha>
--expect-origin <sha> --range <rev>..<rev>` may be used to mechanize checks
1–4, 7, 8, and 10 above; its output is evidence for this report, not a
replacement for it.

This prompt must never:

- edit any file
- stage
- commit
- push
- reset
- merge
- deploy
- mutate Supabase

Return a deterministic report ending in exactly one of:

READY TO PUSH

or

BLOCKED — <exact reason>

This prompt does not itself authorize the push. A separate `MODE: Manual`
authorization is required before `git push` runs.
