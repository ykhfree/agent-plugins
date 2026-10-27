#!/usr/bin/env bash
# Unit test: verdict.py maps one jev result to decide (exit 0), advise (exit 1),
# or bad input (exit 2), by the "Jev decides" and "Jev advises" lists in SKILL.md.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
v="$skill_root/scripts/verdict.py"

# run <expected-exit> <json> <args...>: stores stdout in $out, fails on a wrong exit code.
run() {
  local want="$1" json="$2" got=0
  shift 2
  out="$(printf '%s' "$json" | "$v" "$@" 2>/dev/null)" || got=$?
  if [[ "$got" != "$want" ]]; then
    echo "expected exit $want, got $got for: $* <<< $json" >&2
    exit 1
  fi
}
# has <text>: the last stdout contains text.
has() {
  [[ "$out" == *"$1"* ]] || { echo "missing '$1' in: $out" >&2; exit 1; }
}

# 1) happy path: find absent decides (do not read the file); found decides too.
run 0 '{"verdict": "absent", "uncertain": false, "lines": []}' find
has '"action": "decide"'
has 'do not read it'
run 0 '{"verdict": "found", "uncertain": false, "lines": []}' find
has 'read only the returned lines'

# 2) boundary: no_match means opposite things for rank and which.
run 0 '{"no_match": true, "uncertain": false, "ranked": []}' rank
has 'search another way'
run 1 '{"no_match": true, "uncertain": false, "ranked": []}' which
has 'read the top screen yourself'
run 0 '{"no_match": false, "uncertain": false, "ranked": []}' which

# 3) boundary: uncertain wins over a verdict that would decide.
run 1 '{"verdict": "absent", "uncertain": true, "lines": []}' find
run 1 '{"no_match": true, "uncertain": true, "ranked": []}' rank
run 1 '{"verdict": "ok", "uncertain": true}' locate

# 4) locate: ok decides, unless the click is destructive; unverified and absent advise.
run 0 '{"verdict": "ok", "uncertain": false, "click_px": [10, 20]}' locate
has 'click_px'
run 1 '{"verdict": "ok", "uncertain": false, "click_px": [10, 20]}' locate --destructive
has 'destructive'
run 1 '{"verdict": "unverified", "uncertain": false}' locate
run 1 '{"verdict": "absent", "present": 0.1, "uncertain": false}' locate

# 5) screen decides on exclusions, mentions withheld injections, and advises on conflicting evidence.
run 0 '{"passages": [{"index": 0, "route": "exclude", "reason": "prompt_injection"}]}' screen
has 'do not refetch'
run 1 '{"passages": [{"index": 3, "route": "conflicting_evidence", "text": "x"}]}' screen
has 'passages 3 contradict'

# 6) search and detect always advise; their extra reasons appear.
run 1 '{"uncertain": false, "complete": false, "files": []}' search
has 'narrow ROOT'
run 1 '{"uncertain": false, "complete": true, "files": []}' search
[[ "$out" != *"narrow ROOT"* ]] || { echo "complete search must not say narrow ROOT" >&2; exit 1; }
run 1 '{"objects": [{"label": "dog", "count": "several"}], "absent": []}' detect
has 'count several for dog;'

# 7) a command this skill trusts no verdict of advises.
run 1 '{"verdict": "record"}' memgate
has 'trusts no verdict'

# 8) failure: bad input exits 2 with no stdout.
run 2 'not json' find
[[ -z "$out" ]] || { echo "bad input must print nothing on stdout" >&2; exit 1; }
run 2 '{"verdict": "maybe", "uncertain": false}' find
run 2 '{"uncertain": false}' rank
run 2 '{"passages": "none"}' screen
run 2 '[1, 2]' find
run 2 '{"no_match": false, "uncertain": false}' rank --destructive
run 2 '{}'

echo "verdict_test: ok"
