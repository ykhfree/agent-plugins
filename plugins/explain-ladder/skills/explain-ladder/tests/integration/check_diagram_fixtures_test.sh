#!/usr/bin/env bash
# Integration test: run scripts/check_diagram.py on diagram files in tests/fixtures/diagrams/.
# A file named pass-* must exit 0; a file named fail-* must exit 1 and name its problem.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
checker="$here/../../scripts/check_diagram.py"
fixtures="$here/../fixtures/diagrams"
failures=0

# check <file> <exit-code> <stdout-substring>
check() {
  local file="$fixtures/$1" want_code="$2" want_text="$3" out code=0
  out="$("$checker" "$file" 2>&1)" || code=$?
  if [[ "$code" == "$want_code" && "$out" == *"$want_text"* ]]; then
    echo "ok   $1"
  else
    echo "FAIL $1: exit $code (want $want_code), output: $out"
    failures=$((failures+1))
  fi
}

check pass-web-request.md 0 "OK: 3 boxes, 4 lines"
check fail-box-drawing.md 1 "U+250C"
check fail-too-wide.md 1 "line 1: 79 columns, limit is 72"

[[ $failures -eq 0 ]]
