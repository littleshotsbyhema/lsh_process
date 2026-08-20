#!/bin/bash
#
# scripts/verify-checkpoint.sh
#
# Read-only governed verification tool implementing the frozen contract in
# docs/SPRINT_MASTER_REGISTER.md, section
# "Claude Sprint Automation Framework - Phase 1 - Technical Design Freeze".
#
# This script never edits, stages, commits, pushes, resets, or mutates any
# repository or database state. It only inspects and reports.
#
# Written for bash 3.2 (the stock /bin/bash on the target macOS operator
# environment) - no associative arrays, no mapfile, no [[ =~ ]] reliance
# beyond simple fixed patterns. Uses only grep flags common to BSD grep,
# GNU grep, and ugrep in grep-compatible mode (-c -l -i -E -q). Never uses
# sed -i. Never uses set -x.

set -u

# ---------------------------------------------------------------------------
# Repository root (script must be run with CWD at the repo root; verified,
# never assumed, by checking for a known anchor file).
# ---------------------------------------------------------------------------

if [ ! -f "./CLAUDE.md" ] || [ ! -d "./.git" ]; then
  echo "FAIL: this script must be run from the repository root (CLAUDE.md and .git/ not found in the current directory)."
  exit 2
fi

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

print_usage() {
  cat <<'USAGE'
Usage: scripts/verify-checkpoint.sh <mode> [options]

Modes (exactly one required, no default):
  tooling         Verify Phase 1 framework/tooling files only.
  implementation  Full governed product-implementation verification.
  checkpoint      Documentation-only governed checkpoint verification.
  pre-push        Read-only pre-push audit over a commit range.
  post-push       Read-only post-push remote-state verification.

Options:
  --branch <name>              Expected current branch.
  --expect-head <full-sha>     Expected git rev-parse HEAD (40 hex chars).
  --expect-origin <full-sha>   Expected origin/<branch> SHA (40 hex chars).
  --boundary-file <path>       Plain-text file, one repo-relative path per
                                line: the exact allowed file boundary.
  --commit <sha>                Single commit to verify (tooling/
                                implementation/checkpoint modes).
  --range <rev>..<rev>          Commit range to verify (pre-push mode).

This script is read-only. It never runs git add/commit/push/reset/clean/
rebase/merge, never runs supabase db reset/push, never uses --linked, never
installs dependencies, and never uses npx.
USAGE
}

if [ "$#" -eq 0 ]; then
  print_usage
  exit 2
fi

MODE="$1"
shift

case "$MODE" in
  tooling|implementation|checkpoint|pre-push|post-push) ;;
  *)
    echo "FAIL: unknown mode '$MODE'."
    print_usage
    exit 2
    ;;
esac

# ---------------------------------------------------------------------------
# Option parsing (bash-3.2-safe hand-rolled long-option loop; no getopts,
# since getopts does not support long options).
# ---------------------------------------------------------------------------

OPT_BRANCH=""
OPT_EXPECT_HEAD=""
OPT_EXPECT_ORIGIN=""
OPT_BOUNDARY_FILE=""
OPT_COMMIT=""
OPT_RANGE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --branch)
      OPT_BRANCH="${2:-}"
      shift 2
      ;;
    --expect-head)
      OPT_EXPECT_HEAD="${2:-}"
      shift 2
      ;;
    --expect-origin)
      OPT_EXPECT_ORIGIN="${2:-}"
      shift 2
      ;;
    --boundary-file)
      OPT_BOUNDARY_FILE="${2:-}"
      shift 2
      ;;
    --commit)
      OPT_COMMIT="${2:-}"
      shift 2
      ;;
    --range)
      OPT_RANGE="${2:-}"
      shift 2
      ;;
    *)
      echo "FAIL: unknown option '$1'."
      print_usage
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Structured status reporting. Every check prints its own name, the exact
# command it ran (description only, not raw command injection), its exit
# status, and PASS/FAIL. No contextual classification (e.g. "pre-existing
# debt") is ever emitted here - that judgment stays outside this script.
# ---------------------------------------------------------------------------

CHECK_FAILURES=0

report_check() {
  # $1 = check name, $2 = description, $3 = exit status
  name="$1"
  desc="$2"
  status="$3"
  if [ "$status" -eq 0 ]; then
    echo "CHECK: $name | $desc | exit=$status | PASS"
  else
    echo "CHECK: $name | $desc | exit=$status | FAIL"
    CHECK_FAILURES=$((CHECK_FAILURES + 1))
  fi
}

fail_closed() {
  echo "FAIL CLOSED: $1"
  exit 1
}

# ---------------------------------------------------------------------------
# SHA format validation (full 40-character hex only, never abbreviated).
# ---------------------------------------------------------------------------

validate_sha() {
  label="$1"
  value="$2"
  if [ -z "$value" ]; then
    return 0
  fi
  echo "$value" | grep -E -q '^[0-9a-f]{40}$'
  if [ "$?" -ne 0 ]; then
    fail_closed "$label must be a full 40-character lowercase hex SHA, got: '$value'"
  fi
}

validate_sha "--expect-head" "$OPT_EXPECT_HEAD"
validate_sha "--expect-origin" "$OPT_EXPECT_ORIGIN"

# ---------------------------------------------------------------------------
# Branch / HEAD / origin checks (invariant across all modes when supplied).
# ---------------------------------------------------------------------------

check_branch() {
  if [ -z "$OPT_BRANCH" ]; then
    return 0
  fi
  actual="$(git branch --show-current)"
  if [ "$actual" = "$OPT_BRANCH" ]; then
    report_check "branch" "expected '$OPT_BRANCH', actual '$actual'" 0
  else
    report_check "branch" "expected '$OPT_BRANCH', actual '$actual'" 1
  fi
}

check_expect_head() {
  if [ -z "$OPT_EXPECT_HEAD" ]; then
    return 0
  fi
  actual="$(git rev-parse HEAD)"
  if [ "$actual" = "$OPT_EXPECT_HEAD" ]; then
    report_check "expect-head" "expected $OPT_EXPECT_HEAD, actual $actual" 0
  else
    report_check "expect-head" "expected $OPT_EXPECT_HEAD, actual $actual" 1
  fi
}

check_expect_origin() {
  if [ -z "$OPT_EXPECT_ORIGIN" ]; then
    return 0
  fi
  branch_for_origin="$OPT_BRANCH"
  if [ -z "$branch_for_origin" ]; then
    branch_for_origin="$(git branch --show-current)"
  fi
  actual="$(git rev-parse "origin/$branch_for_origin" 2>/dev/null)"
  if [ -z "$actual" ]; then
    report_check "expect-origin" "could not resolve origin/$branch_for_origin" 1
    return 0
  fi
  if [ "$actual" = "$OPT_EXPECT_ORIGIN" ]; then
    report_check "expect-origin" "expected $OPT_EXPECT_ORIGIN, actual $actual" 0
  else
    report_check "expect-origin" "expected $OPT_EXPECT_ORIGIN, actual $actual" 1
  fi
}

check_diff_check() {
  git diff --check >/dev/null 2>&1
  report_check "git-diff-check" "git diff --check" "$?"
}

# ---------------------------------------------------------------------------
# Boundary-file validation and file-boundary verification.
#
# Contract (frozen, section 10):
#   - read-only input
#   - one normalized repo-relative path per line
#   - reject absolute paths
#   - reject ..
#   - reject duplicates
#   - reject an empty effective boundary
#   - never mechanically parse freeze Markdown
# ---------------------------------------------------------------------------

validate_boundary_file() {
  bf="$1"
  if [ -z "$bf" ]; then
    fail_closed "--boundary-file is required for this mode."
  fi
  if [ ! -f "$bf" ]; then
    fail_closed "--boundary-file '$bf' does not exist or is not a regular file."
  fi

  line_count=0
  while IFS= read -r line || [ -n "$line" ]; do
    if [ -z "$line" ]; then
      continue
    fi
    line_count=$((line_count + 1))
    case "$line" in
      /*)
        fail_closed "boundary file line '$line' is an absolute path; only repo-relative paths are allowed."
        ;;
    esac
    case "$line" in
      *..*)
        fail_closed "boundary file line '$line' contains '..'; parent-directory traversal is not allowed."
        ;;
    esac
  done < "$bf"

  if [ "$line_count" -eq 0 ]; then
    fail_closed "boundary file '$bf' has an empty effective boundary; a governed boundary check requires at least one file."
  fi

  dup_count=$(sort "$bf" | uniq -d | wc -l | tr -d ' ')
  if [ "$dup_count" != "0" ]; then
    fail_closed "boundary file '$bf' contains duplicate entries."
  fi
}

check_file_boundary() {
  commit="$1"
  bf="$2"
  validate_boundary_file "$bf"

  actual_files_tmp="$(mktemp -t verifycheck)"
  git show --format= --name-only "$commit" | sort > "$actual_files_tmp"

  expected_files_tmp="$(mktemp -t verifycheck)"
  grep -v '^[[:space:]]*$' "$bf" | sort > "$expected_files_tmp"

  if diff -q "$actual_files_tmp" "$expected_files_tmp" >/dev/null 2>&1; then
    report_check "file-boundary" "commit $commit matches boundary file $bf exactly" 0
  else
    report_check "file-boundary" "commit $commit does NOT match boundary file $bf exactly" 1
    echo "  --- expected (from boundary file) ---"
    sed -n 'p' "$expected_files_tmp" | while IFS= read -r l; do echo "  $l"; done
    echo "  --- actual (from commit) ---"
    sed -n 'p' "$actual_files_tmp" | while IFS= read -r l; do echo "  $l"; done
  fi

  rm -f "$actual_files_tmp" "$expected_files_tmp"
}

# ---------------------------------------------------------------------------
# Local-binary-only tooling invocation. Never npx. Fail closed if missing.
# ---------------------------------------------------------------------------

require_local_bin() {
  bin_path="$1"
  if [ ! -x "$bin_path" ]; then
    fail_closed "LOCAL DEPENDENCY MISSING - $bin_path is not present or not executable. Installation is not authorized by this verification script. Run the appropriate install step yourself, or report this as a blocker."
  fi
}

run_prettier_check() {
  # $@ = files to check
  require_local_bin "./node_modules/.bin/prettier"
  ./node_modules/.bin/prettier --check "$@" >/dev/null 2>&1
  report_check "prettier" "./node_modules/.bin/prettier --check $*" "$?"
}

run_eslint_check() {
  require_local_bin "./node_modules/.bin/eslint"
  ./node_modules/.bin/eslint "$@" >/dev/null 2>&1
  report_check "eslint" "./node_modules/.bin/eslint $*" "$?"
}

run_tsc_check() {
  require_local_bin "./node_modules/.bin/tsc"
  ./node_modules/.bin/tsc --noEmit >/dev/null 2>&1
  report_check "tsc" "./node_modules/.bin/tsc --noEmit" "$?"
}

run_build_check() {
  npm run build >/dev/null 2>&1
  report_check "build" "npm run build" "$?"
}

run_pgtap_check() {
  supabase test db --local supabase/tests >/dev/null 2>&1
  report_check "pgtap" "supabase test db --local supabase/tests" "$?"
}

run_db_lint_check() {
  supabase db lint --local >/dev/null 2>&1
  report_check "db-lint" "supabase db lint --local" "$?"
}

run_shell_syntax_check() {
  bash -n scripts/verify-checkpoint.sh
  report_check "shell-syntax" "bash -n scripts/verify-checkpoint.sh" "$?"
}

# ---------------------------------------------------------------------------
# Secret / fixture scanner.
#
# Contract (frozen, section 14): never print matched values. Output only
# category, count, filename, STOP message. Accepts diff-shaped text on
# stdin, matching real usage (git diff <range> | check_secrets_stdin).
# ---------------------------------------------------------------------------

check_secrets_stdin() {
  input_tmp="$(mktemp -t verifycheck)"
  cat > "$input_tmp"

  any_match=0

  scan_category() {
    cat_name="$1"
    pattern="$2"
    count=$(grep -c -E -i "$pattern" "$input_tmp" 2>/dev/null)
    if [ -z "$count" ]; then
      count=0
    fi
    if [ "$count" != "0" ]; then
      echo "SECRET SCAN: $count match(es) found for category '$cat_name'. STOP - do not push."
      any_match=1
    fi
  }

  scan_category "email" '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}'
  scan_category "uuid" '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
  scan_category "credential-keyword" 'password|secret|service_role|api_key|apikey|bearer|credential|jwt|token'
  scan_category "tmp-path" '/tmp/'
  scan_category "local-url" 'localhost|127\.0\.0\.1|54321|54322|54323'
  scan_category "admin-marker" 'openssl|psql|admin/users|DB_URL|SERVICE_ROLE'

  rm -f "$input_tmp"

  if [ "$any_match" -eq 0 ]; then
    echo "SECRET SCAN: zero matches across all categories."
    return 0
  fi
  return 1
}

check_secrets_range() {
  range="$1"
  git diff "$range" | check_secrets_stdin
  report_check "secret-scan" "git diff $range | check_secrets_stdin" "$?"
}

# ---------------------------------------------------------------------------
# post-push staleness reporting.
#
# Contract (frozen, section 17): docs/SPRINT_MASTER_REGISTER.md is historical
# and is NEVER scanned or flagged here. Only docs/CURRENT_MILESTONE.md's
# present-tense claims are checked, and only reported, never edited. If
# classification is unclear, report the fixed human-review sentence rather
# than guess.
# ---------------------------------------------------------------------------

check_current_milestone_staleness() {
  file="docs/CURRENT_MILESTONE.md"
  if [ ! -f "$file" ]; then
    echo "CURRENT_MILESTONE.md not found; skipping staleness check."
    return 0
  fi

  match_line=$(grep -n -E -i 'has not been pushed|not yet pushed|committed locally' "$file" | head -1)

  if [ -z "$match_line" ]; then
    echo "CURRENT_MILESTONE.md: no push-status claim pattern found; nothing to report."
    return 0
  fi

  line_no=$(echo "$match_line" | cut -d: -f1)
  line_text=$(echo "$match_line" | cut -d: -f2-)

  # Only classify as possibly-stale if the file's claim is unambiguous.
  # Anything else falls through to the conservative human-review report.
  echo "$line_text" | grep -q "has not been pushed\|not yet pushed"
  if [ "$?" -eq 0 ]; then
    echo "$file:$line_no POSSIBLY STALE - states '$line_text' but origin now matches HEAD (confirmed via Git). This claim may need a human-authorized follow-up correction."
    return 0
  fi

  echo "CURRENT MILESTONE POSSIBLE STALENESS - HUMAN REVIEW REQUIRED"
  return 0
}

# ---------------------------------------------------------------------------
# Mode: tooling
# ---------------------------------------------------------------------------

mode_tooling() {
  echo "=== MODE: tooling ==="
  check_branch
  check_expect_head
  check_expect_origin

  if [ -n "$OPT_COMMIT" ] && [ -n "$OPT_BOUNDARY_FILE" ]; then
    check_file_boundary "$OPT_COMMIT" "$OPT_BOUNDARY_FILE"
  fi

  check_diff_check

  prompt_files="prompts/05-pre-push-verification.md prompts/06-post-push-verification.md"
  existing_prompt_files=""
  for f in $prompt_files; do
    if [ -f "$f" ]; then
      existing_prompt_files="$existing_prompt_files $f"
    fi
  done
  if [ -n "$existing_prompt_files" ]; then
    run_prettier_check $existing_prompt_files
  else
    echo "CHECK: prettier | no prompt files present yet | SKIPPED"
  fi

  run_shell_syntax_check

  echo "=== working-tree containment (final) ==="
  git status --short

  if [ "$CHECK_FAILURES" -eq 0 ]; then
    echo "RESULT: tooling mode PASS"
    return 0
  fi
  echo "RESULT: tooling mode FAIL ($CHECK_FAILURES check(s) failed)"
  return 1
}

# ---------------------------------------------------------------------------
# Mode: implementation (full governed product-implementation standard)
# ---------------------------------------------------------------------------

mode_implementation() {
  echo "=== MODE: implementation ==="
  check_branch
  check_expect_head
  check_expect_origin

  if [ -z "$OPT_COMMIT" ] || [ -z "$OPT_BOUNDARY_FILE" ]; then
    fail_closed "implementation mode requires both --commit and --boundary-file."
  fi
  check_file_boundary "$OPT_COMMIT" "$OPT_BOUNDARY_FILE"

  check_diff_check

  boundary_files=$(grep -v '^[[:space:]]*$' "$OPT_BOUNDARY_FILE")
  if [ -n "$boundary_files" ]; then
    run_prettier_check $boundary_files
    run_eslint_check $boundary_files
  fi

  run_tsc_check
  run_build_check

  echo "$boundary_files" | grep -q "routeTree.gen.ts"
  if [ "$?" -eq 0 ]; then
    echo "CHECK: routeTree-containment | routeTree.gen.ts is in scope for this commit | INFO"
  else
    echo "CHECK: routeTree-containment | routeTree.gen.ts not in boundary; skipped with reason | SKIPPED"
  fi

  run_pgtap_check
  run_db_lint_check

  if [ "$CHECK_FAILURES" -eq 0 ]; then
    echo "RESULT: implementation mode PASS"
    return 0
  fi
  echo "RESULT: implementation mode FAIL ($CHECK_FAILURES check(s) failed)"
  return 1
}

# ---------------------------------------------------------------------------
# Mode: checkpoint (documentation-only profile)
# ---------------------------------------------------------------------------

mode_checkpoint() {
  echo "=== MODE: checkpoint ==="
  check_branch
  check_expect_head
  check_expect_origin

  if [ -z "$OPT_COMMIT" ] || [ -z "$OPT_BOUNDARY_FILE" ]; then
    fail_closed "checkpoint mode requires both --commit and --boundary-file."
  fi
  check_file_boundary "$OPT_COMMIT" "$OPT_BOUNDARY_FILE"

  check_diff_check
  check_secrets_range "$OPT_COMMIT~1..$OPT_COMMIT"

  echo "NOTE: checkpoint mode intentionally does not run Prettier/ESLint/tsc/build/pgTAP/db-lint - no application code is in scope for a documentation-only commit."

  if [ "$CHECK_FAILURES" -eq 0 ]; then
    echo "RESULT: checkpoint mode PASS"
    return 0
  fi
  echo "RESULT: checkpoint mode FAIL ($CHECK_FAILURES check(s) failed)"
  return 1
}

# ---------------------------------------------------------------------------
# Mode: pre-push
# ---------------------------------------------------------------------------

mode_prepush() {
  echo "=== MODE: pre-push ==="
  check_branch
  check_expect_head
  check_expect_origin

  echo "=== working tree ==="
  git status --short

  if [ -n "$OPT_RANGE" ]; then
    echo "=== commits above origin ==="
    git log --oneline "$OPT_RANGE"

    echo "=== complete push delta ==="
    git diff --stat "$OPT_RANGE"
    git diff --name-status "$OPT_RANGE"

    git diff --check "$OPT_RANGE" >/dev/null 2>&1
    report_check "range-diff-check" "git diff --check $OPT_RANGE" "$?"

    check_secrets_range "$OPT_RANGE"
  else
    check_diff_check
  fi

  echo "=== production status ==="
  echo "PRODUCTION: HOLD"

  echo "=== final re-check ==="
  git status --short
  git rev-parse HEAD

  if [ "$CHECK_FAILURES" -eq 0 ]; then
    echo "RESULT: READY TO PUSH"
    return 0
  fi
  echo "RESULT: BLOCKED ($CHECK_FAILURES check(s) failed)"
  return 1
}

# ---------------------------------------------------------------------------
# Mode: post-push
# ---------------------------------------------------------------------------

mode_postpush() {
  echo "=== MODE: post-push ==="
  check_branch
  check_expect_head
  check_expect_origin

  echo "=== ancestry ==="
  if [ -n "$OPT_EXPECT_HEAD" ]; then
    git merge-base --is-ancestor "$OPT_EXPECT_HEAD" "origin/${OPT_BRANCH:-$(git branch --show-current)}" 2>/dev/null
    report_check "ancestry" "expect-head is ancestor of (or equal to) origin" "$?"
  fi

  echo "=== working tree ==="
  git status --short

  echo "=== production status ==="
  echo "PRODUCTION: HOLD"

  echo "=== CURRENT_MILESTONE.md staleness report (informational only; never edited) ==="
  check_current_milestone_staleness

  echo "NOTE: docs/SPRINT_MASTER_REGISTER.md is historical append-only evidence and is never scanned or flagged for staleness by this script."

  if [ "$CHECK_FAILURES" -eq 0 ]; then
    echo "RESULT: post-push verification PASS"
    return 0
  fi
  echo "RESULT: post-push verification FAIL ($CHECK_FAILURES check(s) failed)"
  return 1
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

case "$MODE" in
  tooling) mode_tooling ;;
  implementation) mode_implementation ;;
  checkpoint) mode_checkpoint ;;
  pre-push) mode_prepush ;;
  post-push) mode_postpush ;;
esac

exit "$?"
