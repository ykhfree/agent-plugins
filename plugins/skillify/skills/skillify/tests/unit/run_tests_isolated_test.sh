#!/usr/bin/env bash
# Unit test: run_tests.sh's isolated second pass.
# Verifies (a) HOME-independent tests pass both passes, (b) a test that
# depends on the original $HOME fails the isolated pass and bubbles up to
# exit 1, and (c) SKILLIFY_RUN_TESTS_SKIP_ISOLATED=1 limits execution to
# the default pass.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
runner="$skill_root/scripts/run_tests.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mk_skill() {
  local target="$1"
  mkdir -p "$target/tests/unit" "$target/tests/integration" "$target/tests/e2e"
  printf '%s' "$target"
}

# --- (a) HOME-independent test passes both passes ---
case_a="$(mk_skill "$work/case_a")"
cat > "$case_a/tests/unit/independent.sh" <<'TEST'
#!/usr/bin/env bash
exit 0
TEST
chmod +x "$case_a/tests/unit/independent.sh"

if ! out="$("$runner" "$case_a" 2>&1)"; then
  echo "(a) expected runner to succeed on a HOME-independent test" >&2
  echo "$out" >&2
  exit 1
fi
grep -q '\[default\] attempted=1 ran=1' <<< "$out" \
  || { echo "(a) default-pass summary missing: $out" >&2; exit 1; }
grep -q '\[isolated' <<< "$out" \
  || { echo "(a) isolated-pass summary missing: $out" >&2; exit 1; }

# --- (b) HOME-dependent test fails isolated pass; runner exits 1 ---
# The child test compares its HOME against EXPECTED_HOME (passed through the
# runner since only HOME is overridden, not other env vars).
case_b="$(mk_skill "$work/case_b")"
cat > "$case_b/tests/unit/home_dep.sh" <<'TEST'
#!/usr/bin/env bash
[[ "$HOME" == "$EXPECTED_HOME" ]] || exit 1
exit 0
TEST
chmod +x "$case_b/tests/unit/home_dep.sh"

if EXPECTED_HOME="$HOME" "$runner" "$case_b" >/dev/null 2>&1; then
  echo "(b) expected runner to FAIL because the isolated pass overrides HOME" >&2
  exit 1
fi
out="$(EXPECTED_HOME="$HOME" "$runner" "$case_b" 2>&1 || true)"
grep -q '\[default\] attempted=1 ran=1 skipped=0 failures=0' <<< "$out" \
  || { echo "(b) default pass should still pass: $out" >&2; exit 1; }
grep -q '\[isolated.*\] attempted=1 ran=0 skipped=0 failures=1' <<< "$out" \
  || { echo "(b) isolated pass should report 1 failure: $out" >&2; exit 1; }

# --- (c) SKILLIFY_RUN_TESTS_SKIP_ISOLATED=1 keeps runner at exit 0 ---
out="$(SKILLIFY_RUN_TESTS_SKIP_ISOLATED=1 EXPECTED_HOME="$HOME" "$runner" "$case_b" 2>&1)" \
  && rc=0 || rc=$?
if [[ $rc -ne 0 ]]; then
  echo "(c) escape hatch should bypass isolated pass and exit 0 (got $rc)" >&2
  echo "$out" >&2
  exit 1
fi
grep -q 'SKIPPED via SKILLIFY_RUN_TESTS_SKIP_ISOLATED=1' <<< "$out" \
  || { echo "(c) skip notice not emitted: $out" >&2; exit 1; }

echo "run_tests_isolated_test ok"
