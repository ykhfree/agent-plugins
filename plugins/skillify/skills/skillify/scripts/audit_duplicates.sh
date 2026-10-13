#!/usr/bin/env bash
# Audit for skill name collisions and keyword overlap before authoring a new skill.
# Usage: audit_duplicates.sh <proposed-name> [<keyword> ...]
# Exit codes:
#   0 = no collision and overlap < 3
#   1 = collision OR overlap >= 3
#   2 = bad invocation
set -euo pipefail

name="${1:?usage: audit_duplicates.sh <name> [<keyword> ...]}"
shift || true
keywords=("$@")

roots=(
  "$HOME/.claude/skills"
  "$HOME/.agents/skills"
  "$HOME/.codex/skills"
  "$HOME/.claude/plugins/cache"
  "$HOME/.codex/plugins/cache"
)
[[ -d ".claude/skills" ]] && roots+=(".claude/skills")
[[ -d ".agents/skills" ]] && roots+=(".agents/skills")
[[ -d ".codex/skills" ]] && roots+=(".codex/skills")

# Auto-detect plugin marketplace source trees: walk up from CWD looking for a
# Claude Code or Codex plugin marker, and add the sibling skills/ directory.
# Without this, authoring a new skill in a marketplace repo (where skills live
# at <repo>/skills/<name>/, not <repo>/.claude/skills/<name>/) silently misses
# in-repo collisions.
search_dir="$(pwd)"
while [[ "$search_dir" != "/" ]]; do
  if [[ (-f "$search_dir/.claude-plugin/marketplace.json" \
        || -f "$search_dir/.claude-plugin/plugin.json" \
        || -f "$search_dir/.codex-plugin/plugin.json") \
     && -d "$search_dir/skills" ]]; then
    roots+=("$search_dir/skills")
    break
  fi
  search_dir="$(dirname "$search_dir")"
done

# Explicit override: SKILLIFY_AUDIT_EXTRA_ROOTS is a colon-separated list of
# additional directories to scan. Useful in CI or for cross-repo audits where
# the marketplace marker is not co-located with the audited tree.
if [[ -n "${SKILLIFY_AUDIT_EXTRA_ROOTS:-}" ]]; then
  IFS=':' read -r -a extra_roots <<< "$SKILLIFY_AUDIT_EXTRA_ROOTS"
  for r in "${extra_roots[@]}"; do
    [[ -n "$r" ]] && roots+=("$r")
  done
fi

collisions=0
overlap=0

for root in "${roots[@]}"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r f; do
    dir=$(dirname "$f")
    base=$(basename "$dir")
    if [[ "$base" == "$name" ]]; then
      echo "NAME COLLISION: $f"
      collisions=$((collisions+1))
    fi
    for kw in "${keywords[@]:-}"; do
      [[ -z "$kw" ]] && continue
      if grep -qiF -- "$kw" "$f"; then
        echo "KEYWORD OVERLAP ($kw): $f"
        overlap=$((overlap+1))
      fi
    done
  done < <(find "$root" -name SKILL.md -type f 2>/dev/null)
done

echo "summary: collisions=$collisions overlap_hits=$overlap"

rc=0
[[ $collisions -gt 0 ]] && rc=1
[[ $overlap -ge 3 ]]   && rc=1
exit $rc
