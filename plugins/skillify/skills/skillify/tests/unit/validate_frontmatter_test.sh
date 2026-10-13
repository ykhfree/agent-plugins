#!/usr/bin/env bash
# Unit test: validate.sh frontmatter checks.
# Asserts: valid fixture passes, fixture with bad name in frontmatter fails.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
validate="$skill_root/scripts/validate.sh"

# Single mktemp .claude/skills tree hosts both the happy-path copy and the
# corrupted variant — keeps cleanup to one trap and avoids polluting
# $HOME/.claude/skills.
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT
mkdir -p "$tmp_root/.claude/skills"

# Happy path: pristine fixture staged under a recognized location.
valid="$tmp_root/.claude/skills/valid-skill"
cp -R "$skill_root/tests/fixtures/valid-skill" "$valid"
if ! "$validate" "$valid" >/dev/null; then
  echo "expected valid-skill fixture to pass" >&2
  exit 1
fi

# Boundary: corrupted frontmatter must fail. The dir basename must match the
# corrupted `name` so the corruption surfaces as a frontmatter failure rather
# than a name-mismatch failure.
target="$tmp_root/.claude/skills/BAD_NAME"
cp -R "$skill_root/tests/fixtures/valid-skill" "$target"

python3 - "$target/SKILL.md" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
text = p.read_text()
text = text.replace("name: valid-skill", "name: BAD_NAME")
p.write_text(text)
PY

if "$validate" "$target" >/dev/null 2>&1; then
  echo "expected corrupted frontmatter to fail validation" >&2
  exit 1
fi

echo "validate_frontmatter_test ok"
