#!/usr/bin/env bash
# Unit test: audit_duplicates.sh exits non-zero when a name collision exists.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
audit="$skill_root/scripts/audit_duplicates.sh"

test_home="$(mktemp -d)"
trap 'rm -rf "$test_home"' EXIT
mkdir -p "$test_home/.agents/skills/skillify"
cp "$skill_root/SKILL.md" "$test_home/.agents/skills/skillify/SKILL.md"

# 1) The test fixture exists under an isolated HOME, so proposing "skillify"
#    must trigger a collision and exit 1.
if HOME="$test_home" "$audit" "skillify" "permanent" >/dev/null 2>&1; then
  echo "expected collision on name=skillify, but audit returned 0" >&2
  exit 1
fi

# 2) A clearly novel name with no keyword overlap must exit 0.
if ! HOME="$test_home" "$audit" "totally-unique-skill-name-xyz123" >/dev/null 2>&1; then
  echo "expected unique name to pass audit" >&2
  exit 1
fi

echo "audit_collision_test ok"
