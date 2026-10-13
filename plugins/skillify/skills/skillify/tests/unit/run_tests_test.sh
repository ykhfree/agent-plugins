#!/usr/bin/env bash
# Unit test: run_tests.sh treats non-executable test files as failures and
# never reports success when zero tests actually ran.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
runner="$skill_root/scripts/run_tests.sh"

# Build a synthetic minimal "skill" tree (only tests/ matters here — run_tests.sh
# does not validate other directories).
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mk_skill() {
  local target="$1"
  rm -rf "$target"
  mkdir -p "$target/tests/unit" "$target/tests/integration" "$target/tests/e2e"
  echo "$target"
}

write_pass() {
  local f="$1"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$f"
  chmod +x "$f"
}

write_fail() {
  local f="$1"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$f"
  chmod +x "$f"
}

write_nonexec() {
  local f="$1"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$f"
  # explicitly NO chmod +x
}

# --- (a) happy path: one passing unit test ---
case_a="$(mk_skill "$work/case_a")"
write_pass "$case_a/tests/unit/pass_test.sh"
if ! out=$("$runner" "$case_a" 2>&1); then
  echo "(a) expected runner to succeed on a single passing unit test" >&2
  echo "$out" >&2
  exit 1
fi
echo "$out" | grep -q "attempted=1 ran=1 skipped=0 failures=0" \
  || { echo "(a) summary line missing or wrong: $out" >&2; exit 1; }

# --- (b) all candidate files non-executable: must fail ---
case_b="$(mk_skill "$work/case_b")"
write_nonexec "$case_b/tests/unit/silent_test.sh"
if "$runner" "$case_b" >/dev/null 2>&1; then
  echo "(b) expected runner to fail when every test file is non-executable" >&2
  exit 1
fi

# --- (c) empty test directories: must fail (no tests executed) ---
case_c="$(mk_skill "$work/case_c")"
if "$runner" "$case_c" >/dev/null 2>&1; then
  echo "(c) expected runner to fail when no test files exist at all" >&2
  exit 1
fi

# --- (d) one passing + one failing: must fail ---
case_d="$(mk_skill "$work/case_d")"
write_pass "$case_d/tests/unit/pass_test.sh"
write_fail "$case_d/tests/integration/fail_test.sh"
if "$runner" "$case_d" >/dev/null 2>&1; then
  echo "(d) expected runner to fail when at least one test fails" >&2
  exit 1
fi

# --- (e) all pass across layers: must succeed and report attempted == ran ---
case_e="$(mk_skill "$work/case_e")"
write_pass "$case_e/tests/unit/u1.sh"
write_pass "$case_e/tests/integration/i1.sh"
write_pass "$case_e/tests/e2e/e1.sh"
if ! out=$("$runner" "$case_e" 2>&1); then
  echo "(e) expected runner to succeed when every test passes across layers" >&2
  echo "$out" >&2
  exit 1
fi
echo "$out" | grep -q "attempted=3 ran=3 skipped=0 failures=0" \
  || { echo "(e) summary line missing or wrong: $out" >&2; exit 1; }

# --- (f) mixed exec/non-exec: must fail because non-exec is now counted ---
case_f="$(mk_skill "$work/case_f")"
write_pass    "$case_f/tests/unit/pass_test.sh"
write_nonexec "$case_f/tests/unit/forgot_chmod_test.sh"
if "$runner" "$case_f" >/dev/null 2>&1; then
  echo "(f) expected runner to fail when any candidate test was silently skipped (non-exec)" >&2
  exit 1
fi

echo "run_tests_test ok"
