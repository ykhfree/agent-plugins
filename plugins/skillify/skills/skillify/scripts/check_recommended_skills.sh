#!/usr/bin/env bash
# Report which of skillify's recommended sub-skills are installed in the
# current runtime. Informational only.
#
# Usage:   check_recommended_skills.sh
# Output:  one line per recommended skill, "<name> present" or "<name> absent"
# Exit:    always 0 (informational; never blocks a workflow)
set -euo pipefail

# Recommended skills referenced from skillify/SKILL.md.
# Claude Code helpers use "<plugin>:<skill-name>"; Codex uses the skill name.
recommended=(
  "skill-creator"
  "superpowers:writing-skills"
  "superpowers:test-driven-development"
  "superpowers:verification-before-completion"
  "claude-plugins-official:skill-creator"
)

for entry in "${recommended[@]}"; do
  name="${entry##*:}"
  if [[ "$entry" == "skill-creator" ]]; then
    roots=(
      "$HOME/.agents/skills"
      "$HOME/.codex/skills"
      "$HOME/.codex/plugins/cache"
    )
  else
    roots=(
      "$HOME/.claude/skills"
      "$HOME/.claude/plugins/cache"
    )
  fi
  found=""
  for root in "${roots[@]}"; do
    [[ -d "$root" ]] || continue
    # Match any SKILL.md whose parent directory equals the skill name,
    # at any depth under the root. Quietly ignore find errors.
    hit="$(find "$root" -type f -name SKILL.md -path "*/${name}/SKILL.md" 2>/dev/null | head -n 1 || true)"
    if [[ -n "$hit" ]]; then
      found="$hit"
      break
    fi
  done
  if [[ -n "$found" ]]; then
    echo "${entry} present (${found})"
  else
    echo "${entry} absent"
  fi
done
