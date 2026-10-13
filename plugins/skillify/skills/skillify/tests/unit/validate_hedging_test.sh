#!/usr/bin/env bash
# Unit test: validate.sh rejects SKILL.md bodies containing hedging language.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
validate="$skill_root/scripts/validate.sh"

# Stage fixtures into a mktemp .claude/skills tree so the location gate is
# satisfied — otherwise validation would fail on location, not on hedging,
# and the assertion below would be meaningless.
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT
mkdir -p "$tmp_root/.claude/skills"
hedging="$tmp_root/.claude/skills/hedging-skill"
valid="$tmp_root/.claude/skills/valid-skill"
cp -R "$skill_root/tests/fixtures/hedging-skill" "$hedging"
cp -R "$skill_root/tests/fixtures/valid-skill" "$valid"

if "$validate" "$hedging" >/dev/null 2>&1; then
  echo "expected hedging-skill fixture to FAIL validation, but it passed" >&2
  exit 1
fi

# And the inverse: valid-skill must still pass after we asserted hedging fails.
if ! "$validate" "$valid" >/dev/null; then
  echo "valid-skill regression: expected pass" >&2
  exit 1
fi

echo "validate_hedging_test ok"
