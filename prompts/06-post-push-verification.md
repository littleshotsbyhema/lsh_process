# Claude Code Prompt — Post-Push Verification

MODE: Auto

Read CLAUDE.md first.

This prompt runs only after a separately Manual-authorized `git push` has
already happened. It never performs or authorizes a push itself.

Require these exact inputs before starting:

- branch
- expected local HEAD (full SHA)
- expected remote/origin HEAD (full SHA, i.e. what origin should now be)
- expected pushed commits
- production status

Then inspect the repository without making changes.

Verify:

1. Local HEAD matches the expected SHA.
2. Origin HEAD matches the expected SHA.
3. Remote match: local HEAD and origin HEAD are identical (or the expected
   ancestry relationship holds).
4. Expected ancestry: the previously-expected pre-push HEAD is an ancestor
   of (or equal to) the new origin HEAD.
5. Working tree is clean.
6. Each expected pushed commit is present in `git log`.
7. Production status is explicitly HOLD unless a separately governed
   release procedure states otherwise.

Git/origin is the sole authoritative source for whether the push landed.
Do not infer push status from prose in any document.

`scripts/verify-checkpoint.sh post-push --branch <name> --expect-head <sha>
--expect-origin <sha>` may be used to mechanize checks 1–5 above; its output
is evidence for this report, not a replacement for it.

## CURRENT_MILESTONE.md staleness (report only)

`docs/CURRENT_MILESTONE.md` is the mutable execution pointer. After
confirming the push landed via Git, check this file only — never
`docs/SPRINT_MASTER_REGISTER.md` — for a present-tense push-status claim
that may now contradict Git (e.g. "has not been pushed", "not yet pushed").

- If a clear, unambiguous stale claim is found, report it by exact file and
  line, quoting the sentence, and note that origin now matches HEAD.
- If the prose cannot be classified safely, report exactly:

  CURRENT MILESTONE POSSIBLE STALENESS — HUMAN REVIEW REQUIRED

  Do not guess.

- Never edit `docs/CURRENT_MILESTONE.md` as part of this prompt. A
  correction, if warranted, is its own separate, explicitly authorized
  documentation commit.

## Historical evidence (never treated as stale)

`docs/SPRINT_MASTER_REGISTER.md` is historical, append-only governance
evidence. A checkpoint sentence there stating a commit "has not been
pushed" was true at checkpoint-commit time and remains a correct historical
record forever. This prompt never scans the register for staleness, never
flags it, and never suggests editing it.

This prompt must never:

- edit any file
- stage
- commit
- push
- reset
- merge
- deploy
- mutate Supabase
- rewrite historical or mutable documentation

Return a deterministic remote-verification report stating local HEAD,
origin HEAD, remote match (YES/NO), ancestry result, working-tree state,
the CURRENT_MILESTONE.md staleness finding (or absence of one), and
production status.
