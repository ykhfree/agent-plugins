#!/usr/bin/env bash
# Gate 10 of validate.sh — reject any test under <skill-dir>/tests/*.sh that
# references a real Claude Code or Codex skill directory outside a comment.
# Tests must use mktemp + HOME= injection so the suite never pollutes the
# runtime's actual skill directories.
#
# Usage: check_test_home_pollution.sh <skill-dir>
# Exit codes:
#   0  no pollution found (or no tests/ directory)
#   1  pollution found — offending file:line:content printed to stderr
#   2  bad invocation
set -euo pipefail

skill_dir="${1:?usage: check_test_home_pollution.sh <skill-dir>}"
[[ -d "$skill_dir" ]] || { echo "not a directory: $skill_dir" >&2; exit 2; }
tests_dir="$skill_dir/tests"
[[ -d "$tests_dir" ]] || exit 0

# awk skips comment-only lines first, then matches the bad pattern. Using awk
# (not grep -v) avoids the false-positive case where a non-comment line
# happens to contain ":#" somewhere in its content.
hits="$(
  find "$tests_dir" -type f -name '*.sh' \
    -not -path '*/fixtures/*' \
    -print0 \
    | xargs -0 awk '
        /^[[:space:]]*#/ { next }
        /(\$HOME|~)\/\.(claude|agents|codex)\/skills\// {
          printf "%s:%d: %s\n", FILENAME, FNR, $0
        }
      '
)"

if [[ -n "$hits" ]]; then
  printf '%s\n' "$hits" >&2
  exit 1
fi
exit 0
