#!/usr/bin/env bash
# Integration test: validate.sh's gate 10 must reject the polluting-skill
# fixture (which deliberately writes to real $HOME/.claude/skills/ in a unit
# test) while passing every prior gate. Stage the fixture into mktemp's
# .claude/skills/ tree first so the location gate (gate 9) is satisfied.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
validate="$skill_root/scripts/validate.sh"
fixture="$skill_root/tests/fixtures/polluting-skill"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT
mkdir -p "$tmp_root/.claude/skills"
staged="$tmp_root/.claude/skills/polluting-skill"
cp -R "$fixture" "$staged"

stderr_file="$(mktemp)"
trap 'rm -rf "$tmp_root" "$stderr_file"' EXIT

if "$validate" "$staged" >/dev/null 2>"$stderr_file"; then
  echo "expected validate.sh to FAIL on polluting-skill, but it passed" >&2
  cat "$stderr_file" >&2
  exit 1
fi

# The failure must come from gate 10, not an earlier gate (regression check).
grep -q 'tests pollute real runtime skill directories' "$stderr_file" \
  || { echo "expected gate-10 message in stderr, got:" >&2; cat "$stderr_file" >&2; exit 1; }

echo "validate_blocks_polluting_test ok"
