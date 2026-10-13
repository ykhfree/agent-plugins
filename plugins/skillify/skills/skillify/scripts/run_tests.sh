#!/usr/bin/env bash
# Run all unit + integration + E2E tests for a skill directory in order,
# TWICE: once with the inherited environment, once with HOME redirected to
# a throwaway mktemp dir. Both passes MUST exit cleanly. The isolated pass
# closes the dynamic side of the "tests pass on my machine but fail in a
# sandboxed environment" failure class — gate 10 catches it statically,
# but a script can still depend on real $HOME without referencing it as a
# bare path (for example, reading a real home-directory config).
#
# Usage:        run_tests.sh <skill-dir>
# Exit codes:   0 = both passes ran AND no failures in either
#               1 = any failure, OR zero tests executed in either pass
#               2 = bad invocation
#
# Escape hatch: SKILLIFY_RUN_TESTS_SKIP_ISOLATED=1 runs only the default
#               pass. Use sparingly — the isolated pass is the safety net.
#
# Output:       per-test result lines plus a per-pass summary
#                   [<pass>] attempted=A ran=R skipped=S failures=F
#               where A = R + S + F. Non-executable test files emit a
#               WARN to stderr — they were a real silent-skip footgun
#               before this script started counting them.
set -euo pipefail

d="${1:?usage: run_tests.sh <skill-dir>}"
[[ -d "$d" ]] || { echo "not a directory: $d" >&2; exit 2; }

# run_pass <label> <home-override-or-empty> -> echoes summary, returns 0/1.
run_pass() {
  local label="$1" home_override="$2"
  local attempted=0 ran=0 skipped=0 failures=0

  echo "=== pass: $label ==="
  for layer in unit integration e2e; do
    [[ -d "$d/tests/$layer" ]] || continue
    for t in "$d"/tests/$layer/*.sh; do
      [[ -f "$t" ]] || continue
      attempted=$((attempted+1))
      if [[ ! -x "$t" ]]; then
        echo "WARN: skipped non-executable test: $t" >&2
        skipped=$((skipped+1))
        continue
      fi
      echo "== $layer/$(basename "$t") =="
      if [[ -n "$home_override" ]]; then
        if HOME="$home_override" "$t"; then
          ran=$((ran+1))
        else
          echo "FAIL: $t" >&2
          failures=$((failures+1))
        fi
      else
        if "$t"; then
          ran=$((ran+1))
        else
          echo "FAIL: $t" >&2
          failures=$((failures+1))
        fi
      fi
    done
  done

  echo "[$label] attempted=$attempted ran=$ran skipped=$skipped failures=$failures"
  if [[ $failures -gt 0 ]]; then
    return 1
  fi
  if [[ $skipped -gt 0 ]]; then
    echo "[$label] non-executable test files were silently skipped — chmod +x them or move them out of tests/{unit,integration,e2e}/" >&2
    return 1
  fi
  if [[ $ran -eq 0 ]]; then
    echo "[$label] no tests executed: tests/{unit,integration,e2e}/ contained no test files" >&2
    return 1
  fi
  return 0
}

# Pass 1: default environment.
run_pass "default" "" || exit 1

# Pass 2: isolated HOME. Gives each test a fresh, throwaway $HOME so any
# script that reads from the real HOME fails loudly here even if its source
# doesn't write a bare runtime skill path (which
# gate 10 already catches).
if [[ "${SKILLIFY_RUN_TESTS_SKIP_ISOLATED:-0}" == "1" ]]; then
  echo "[isolated] SKIPPED via SKILLIFY_RUN_TESTS_SKIP_ISOLATED=1" >&2
  exit 0
fi

isolated_home="$(mktemp -d)"
trap 'rm -rf "$isolated_home"' EXIT
run_pass "isolated (HOME=$isolated_home)" "$isolated_home" || exit 1
exit 0
