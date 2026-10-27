#!/usr/bin/env bash
# Unit test: route.py applies the step rules in order, maps search facts,
# and enforces the advisor budget. Exit 0 follow, 1 policy stop, 2 bad input.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
r="$skill_root/scripts/route.py"

# run <expected-exit> <args...>: stores stdout in $out, fails on a wrong exit code.
run() {
  local want="$1" got=0
  shift
  out="$("$r" "$@" 2>/dev/null)" || got=$?
  if [[ "$got" != "$want" ]]; then
    echo "expected exit $want, got $got for: $*" >&2
    exit 1
  fi
}
# route_is <rule> <route-json>: the last output has that rule and route.
route_is() {
  if ! printf '%s' "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if (d['rule'], d['route']) == ($1, $2) else 1)"; then
    echo "expected rule $1 route $2, got: $out" >&2
    exit 1
  fi
}

# 1) happy path: each step rule alone.
run 0 step exact-edit;        route_is 1 '["main"]'
run 0 step undecided;         route_is 3 '["deep-reasoner"]'
run 0 step product-behavior;  route_is 4 '["main"]'
run 0 step fully-specified;   route_is 5 '["fast-worker"]'

# 2) boundary: order. An exact edit wins over a fully specified one (no fast-worker for
#    an edit you can state), and a costly decision wins over undecided.
run 0 step fully-specified exact-edit;           route_is 1 '["main"]'
run 0 step undecided costly-decision options-open; route_is 2 '["deep-reasoner", "critic", "advisor"]'
run 0 step costly-decision;                      route_is 2 '["advisor"]'
run 0 step fully-specified product-behavior splits-by-context; route_is 4 '["feature-developer"]'

# 3) boundary: the advisor budget. Consults 0..2 are allowed; the 4th (3 made) goes to the user.
run 0 advisor repeat-error --consults 0; route_is '"advisor"' '["advisor"]'
run 0 advisor declare-done --consults 2; route_is '"advisor"' '["advisor"]'
run 1 advisor declare-done --consults 3; route_is '"advisor"' '["user"]'
run 0 advisor trivial --consults 9;      route_is '"advisor"' '[]'

# 4) search facts.
run 0 search locate;    route_is '"search"' '["fast-explorer"]'
run 0 search few-calls; route_is '"search"' '["main"]'
run 0 search why;       route_is '"search"' '["deep-reasoner"]'

# 5) default: no step fact holds, so the step is yours.
run 0 step;             route_is '"default"' '["main"]'

# 6) failure: bad input exits 2 with no stdout.
run 2 step options-open
[[ -z "$out" ]] || { echo "bad input must print nothing on stdout" >&2; exit 1; }
run 2 step splits-by-context fully-specified
run 2 step easy
run 2 search locate trace
run 2 advisor repeat-error --consults -1
run 2 advisor guess --consults 0
run 2 advisor repeat-error
run 2 plan exact-edit
run 2

echo "route_test: ok"
