#!/usr/bin/env bash
# Integration test: skillify must satisfy its own validate.sh gate.
# This is the canonical dog-fooding check — skillify is its own first conformance test.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
validate="$skill_root/scripts/validate.sh"

# Stage skillify into a mktemp .claude/skills tree so the location gate matches
# `*/.claude/skills/*` regardless of where this test runs from (source tree,
# rsync target, or plugin cache).
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT
mkdir -p "$tmp_root/.claude/skills"
staged="$tmp_root/.claude/skills/skillify"
cp -R "$skill_root" "$staged"

if ! "$validate" "$staged" >/dev/null; then
  echo "skillify FAILED its own validator — fix the skill before shipping" >&2
  exit 1
fi

echo "validate_against_self_test ok"
