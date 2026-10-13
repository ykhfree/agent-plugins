#!/usr/bin/env bash
# Integration test: a SKILL.md authored from skillify's (D1) inline fallback
# (zero references to recommended sub-skills) MUST pass validate.sh and MUST
# NOT emit any WARN line, even when the runtime has no recommended skills
# installed.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
validate="$skill_root/scripts/validate.sh"
fixture="$skill_root/tests/fixtures/no-recommended-skill"

# Stage the fixture under a mktemp .claude/skills tree so the location check
# passes without polluting $HOME/.claude/skills.
target_name="no-recommended-skill-$$"
tmp_root="$(mktemp -d)"
target="$tmp_root/.claude/skills/$target_name"
trap 'rm -rf "$tmp_root"' EXIT

mkdir -p "$tmp_root/.claude/skills"
cp -R "$fixture" "$target"

# Rewrite frontmatter name to match the temp directory name.
python3 - "$target/SKILL.md" "$target_name" <<'PY'
import sys, pathlib, re
md, new_name = sys.argv[1], sys.argv[2]
p = pathlib.Path(md)
text = p.read_text()
text = re.sub(r"^name: .*$", f"name: {new_name}", text, count=1, flags=re.M)
p.write_text(text)
PY

stderr_file="$(mktemp)"
trap 'rm -rf "$tmp_root" "$stderr_file"' EXIT

if ! "$validate" "$target" >/dev/null 2>"$stderr_file"; then
  echo "no_recommended_skill_fallback_test: expected validate.sh to pass" >&2
  cat "$stderr_file" >&2
  exit 1
fi

# The fixture has zero recommended-skill references, so no WARN is allowed.
if grep -q '^WARN:' "$stderr_file"; then
  echo "no_recommended_skill_fallback_test: unexpected WARN emitted" >&2
  cat "$stderr_file" >&2
  exit 1
fi

echo "no_recommended_skill_fallback_test ok"
