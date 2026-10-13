#!/usr/bin/env bash
# Integration test: validate.sh MUST emit a WARN to stderr when SKILL.md
# references a recommended sub-skill that is not installed in the runtime,
# while still exiting 0 (the policy is the 9 hard gates; recommended skills
# are advisory).
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
validate="$skill_root/scripts/validate.sh"
seed="$skill_root/tests/fixtures/valid-skill"

# Build a synthetic skill that references a recommended sub-skill, placed
# under a mktemp .claude/skills tree so the location check passes without
# polluting $HOME/.claude/skills.
target_name="warns-recommended-missing-$$"
tmp_root="$(mktemp -d)"
target="$tmp_root/.claude/skills/$target_name"

# Override HOME so check_recommended_skills.sh sees an empty plugin tree.
fake_home="$(mktemp -d)"

trap 'rm -rf "$tmp_root" "$fake_home"' EXIT

mkdir -p "$target"
cp -R "$seed"/. "$target/"

# Rewrite frontmatter name so it matches the directory, and inject a
# reference to a recommended sub-skill into the body.
python3 - "$target/SKILL.md" "$target_name" <<'PY'
import sys, pathlib, re
md, new_name = sys.argv[1], sys.argv[2]
p = pathlib.Path(md)
text = p.read_text()
text = re.sub(r"^name: .*$", f"name: {new_name}", text, count=1, flags=re.M)
text += "\n## Note\n- This skill recommends `superpowers:writing-skills` for SKILL.md authoring.\n"
p.write_text(text)
PY

stderr_file="$(mktemp)"
trap 'rm -rf "$tmp_root" "$fake_home" "$stderr_file"' EXIT

# Run validate against the synthetic skill, with HOME pointing at the empty
# fake_home so the recommended-skill probe reports absent.
if ! HOME="$fake_home" "$validate" "$target" >/dev/null 2>"$stderr_file"; then
  echo "validate_warns_when_recommended_missing_test: expected exit 0" >&2
  cat "$stderr_file" >&2
  exit 1
fi

if ! grep -q 'WARN: SKILL.md references superpowers:writing-skills' "$stderr_file"; then
  echo "validate_warns_when_recommended_missing_test: expected WARN line not found" >&2
  cat "$stderr_file" >&2
  exit 1
fi

echo "validate_warns_when_recommended_missing_test ok"
