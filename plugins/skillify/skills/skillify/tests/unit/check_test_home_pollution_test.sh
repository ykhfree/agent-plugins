#!/usr/bin/env bash
# Unit test: check_test_home_pollution.sh — gate 10 of validate.sh.
# Each case stages a fixture from tests/fixtures/pollution-cases/ into a
# fresh skill dir's tests/unit/sample.sh, then runs the gate. Keeping the
# bad-pattern source content under tests/fixtures/ keeps the unit test
# itself sandbox-safe (gate 10 skips paths matching */fixtures/*).
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
script="$skill_root/scripts/check_test_home_pollution.sh"
cases_dir="$skill_root/tests/fixtures/pollution-cases"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

stage_case() {
  local fixture_name="$1" target_skill="$2"
  local dir="$tmp_root/$target_skill"
  mkdir -p "$dir/tests/unit"
  cp "$cases_dir/$fixture_name" "$dir/tests/unit/sample.sh"
  chmod +x "$dir/tests/unit/sample.sh"
  printf '%s' "$dir"
}

# (a) Clean fixture using mktemp pattern → exit 0.
stage_case clean-mktemp.sh a >/dev/null
"$script" "$tmp_root/a" >/dev/null \
  || { echo "(a) clean fixture expected exit 0" >&2; exit 1; }

# (b) Direct mkdir into real $HOME/.claude/skills/ → exit 1.
stage_case mkdir-bad.sh b >/dev/null
out="$("$script" "$tmp_root/b" 2>&1)" && rc=$? || rc=$?
[[ $rc -eq 1 ]] || { echo "(b) expected exit 1, got $rc: $out" >&2; exit 1; }
grep -q '\.claude/skills/' <<< "$out" \
  || { echo "(b) expected stderr to contain offending line, got: $out" >&2; exit 1; }

# (b2) Direct mkdir into real $HOME/.agents/skills/ → exit 1.
stage_case agents-mkdir-bad.sh b2 >/dev/null
out="$("$script" "$tmp_root/b2" 2>&1)" && rc=$? || rc=$?
[[ $rc -eq 1 ]] || { echo "(b2) expected exit 1, got $rc: $out" >&2; exit 1; }
grep -q '\.agents/skills/' <<< "$out" \
  || { echo "(b2) expected stderr to contain offending line, got: $out" >&2; exit 1; }

# (b3) Direct mkdir into real $HOME/.codex/skills/ → exit 1.
stage_case codex-mkdir-bad.sh b3 >/dev/null
out="$("$script" "$tmp_root/b3" 2>&1)" && rc=$? || rc=$?
[[ $rc -eq 1 ]] || { echo "(b3) expected exit 1, got $rc: $out" >&2; exit 1; }
grep -q '\.codex/skills/' <<< "$out" \
  || { echo "(b3) expected stderr to contain offending line, got: $out" >&2; exit 1; }

# (c) target= assignment using $HOME → exit 1.
stage_case assign-bad.sh c >/dev/null
out="$("$script" "$tmp_root/c" 2>&1)" && rc=$? || rc=$?
[[ $rc -eq 1 ]] || { echo "(c) expected exit 1, got $rc: $out" >&2; exit 1; }

# (d) Reference inside a comment only → exit 0.
stage_case comment-only.sh d >/dev/null
"$script" "$tmp_root/d" >/dev/null \
  || { echo "(d) comment-only reference expected exit 0" >&2; exit 1; }

# (e) HOME=$fake injection without a real runtime path literal → exit 0.
stage_case home-injection.sh e >/dev/null
"$script" "$tmp_root/e" >/dev/null \
  || { echo "(e) HOME-injection pattern expected exit 0" >&2; exit 1; }

# (f) Files under tests/fixtures/ are skipped, even if they pollute.
mkdir -p "$tmp_root/f/tests/fixtures/inner-skill/tests/unit"
cp "$cases_dir/inner-fixture-pollution.sh" \
   "$tmp_root/f/tests/fixtures/inner-skill/tests/unit/bad.sh"
"$script" "$tmp_root/f" >/dev/null \
  || { echo "(f) fixtures path should be skipped, expected exit 0" >&2; exit 1; }

# (g) No tests/ directory at all → exit 0.
mkdir -p "$tmp_root/g"
"$script" "$tmp_root/g" >/dev/null \
  || { echo "(g) skill without tests/ should exit 0" >&2; exit 1; }

# (h) Bad invocation (missing argument) → non-zero.
out="$("$script" 2>&1)" && rc=$? || rc=$?
[[ $rc -ne 0 ]] || { echo "(h) missing arg expected non-zero exit" >&2; exit 1; }

echo "check_test_home_pollution_test ok"
