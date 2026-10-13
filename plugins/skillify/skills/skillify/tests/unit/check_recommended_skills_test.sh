#!/usr/bin/env bash
# Unit test: check_recommended_skills.sh.
# - Case A: empty HOME → all five skills reported absent, exit 0.
# - Cases B-D: one Claude/Codex skill staged under HOME → only that skill
#   reports present, the others absent, exit 0.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
checker="$skill_root/scripts/check_recommended_skills.sh"

[[ -x "$checker" ]] || { echo "checker not executable: $checker" >&2; exit 1; }

# --- Case A: empty HOME ---
tmp_a="$(mktemp -d)"
trap 'rm -rf "$tmp_a"' EXIT

out_a="$(HOME="$tmp_a" "$checker")"
absent_count="$(printf '%s\n' "$out_a" | grep -c " absent$" || true)"
if [[ "$absent_count" -ne 5 ]]; then
  echo "Case A: expected 5 absent lines, got $absent_count" >&2
  printf '%s\n' "$out_a" >&2
  exit 1
fi

# --- Case B: stage one recommended skill under HOME ---
tmp_b="$(mktemp -d)"
trap 'rm -rf "$tmp_a" "$tmp_b"' EXIT

mkdir -p "$tmp_b/.claude/plugins/cache/superpowers-marketplace/superpowers/skills/writing-skills"
echo "stub" > "$tmp_b/.claude/plugins/cache/superpowers-marketplace/superpowers/skills/writing-skills/SKILL.md"

out_b="$(HOME="$tmp_b" "$checker")"

if ! printf '%s\n' "$out_b" | grep -qE '^superpowers:writing-skills present '; then
  echo "Case B: expected superpowers:writing-skills to be present" >&2
  printf '%s\n' "$out_b" >&2
  exit 1
fi

other_absent="$(printf '%s\n' "$out_b" | grep -cE ' absent$' || true)"
if [[ "$other_absent" -ne 4 ]]; then
  echo "Case B: expected 4 other skills absent, got $other_absent" >&2
  printf '%s\n' "$out_b" >&2
  exit 1
fi

# --- Case C: stage the Codex skill-creator under HOME ---
tmp_c="$(mktemp -d)"
trap 'rm -rf "$tmp_a" "$tmp_b" "$tmp_c"' EXIT

mkdir -p "$tmp_c/.codex/skills/.system/skill-creator"
echo "stub" > "$tmp_c/.codex/skills/.system/skill-creator/SKILL.md"

out_c="$(HOME="$tmp_c" "$checker")"
if ! printf '%s\n' "$out_c" | grep -qE '^skill-creator present '; then
  echo "Case C: expected skill-creator to be present" >&2
  printf '%s\n' "$out_c" >&2
  exit 1
fi

other_absent="$(printf '%s\n' "$out_c" | grep -cE ' absent$' || true)"
if [[ "$other_absent" -ne 4 ]]; then
  echo "Case C: expected 4 other skills absent, got $other_absent" >&2
  printf '%s\n' "$out_c" >&2
  exit 1
fi

# --- Case D: stage the Claude plugin skill-creator under HOME ---
tmp_d="$(mktemp -d)"
trap 'rm -rf "$tmp_a" "$tmp_b" "$tmp_c" "$tmp_d"' EXIT

mkdir -p "$tmp_d/.claude/plugins/cache/claude-plugins-official/skill-creator/1.0.0/skills/skill-creator"
echo "stub" > "$tmp_d/.claude/plugins/cache/claude-plugins-official/skill-creator/1.0.0/skills/skill-creator/SKILL.md"

out_d="$(HOME="$tmp_d" "$checker")"
if ! printf '%s\n' "$out_d" | grep -qE '^claude-plugins-official:skill-creator present '; then
  echo "Case D: expected claude-plugins-official:skill-creator to be present" >&2
  printf '%s\n' "$out_d" >&2
  exit 1
fi
if ! printf '%s\n' "$out_d" | grep -qE '^skill-creator absent$'; then
  echo "Case D: expected Codex skill-creator to remain absent" >&2
  printf '%s\n' "$out_d" >&2
  exit 1
fi

echo "check_recommended_skills_test ok"
