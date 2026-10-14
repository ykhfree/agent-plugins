#!/usr/bin/env bash
# Unit tests for scripts/check_diagram.py: happy paths, boundaries, failures.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
checker="$here/../../scripts/check_diagram.py"
failures=0

# expect <name> <exit-code> <stdout-substring> : diagram text on stdin.
expect() {
  local name="$1" want_code="$2" want_text="$3" out code=0
  out="$("$checker" 2>&1)" || code=$?
  if [[ "$code" == "$want_code" && "$out" == *"$want_text"* ]]; then
    echo "ok   $name"
  else
    echo "FAIL $name: exit $code (want $want_code), output: $out"
    failures=$((failures+1))
  fi
}

# row <n> : one row of n boxes, 3 lines.
row() {
  local n="$1" top="" mid="" i
  for ((i = 0; i < n; i++)); do top+="+---+ "; mid+="| A | "; done
  printf '%s\n%s\n%s\n' "$top" "$mid" "$top"
}

# line_of <width> : a 3-box row whose first line is padded to <width> columns.
line_of() {
  local width="$1" top="+---+ +---+ +---+"
  printf '%s%*s\n' "$top" $((width - ${#top})) "x"
  printf '| A | | B | | C |\n+---+ +---+ +---+\n'
}

expect "happy: three ASCII boxes" 0 "OK: 3 boxes" < <(row 3)
expect "happy: Hangul names align by display width" 0 "OK: 3 boxes" < <(
  printf '%s\n' '+----------+        +------+' '| 브라우저 | -----> | 서버 |' '+----------+        +------+' \
    '     |' '     v' '+--------------+' '| 데이터베이스 |' '+--------------+')
expect "happy: fullwidth letters count as 2 columns" 0 "OK: 3 boxes" < <(
  printf '%s\n' '+------+ +---+ +---+' '| ＡＢ | | C | | D |' '+------+ +---+ +---+')
expect "happy: stacked boxes that share an edge" 0 "OK: 3 boxes" < <(
  printf '%s\n' '+---+' '| A |' '+---+' '| B |' '+---+' '| C |' '+---+')
expect "happy: code fences are removed" 0 "OK: 3 boxes, 3 lines" < <(echo '```'; row 3; echo '```')

expect "boundary: 72 columns passes" 0 "OK: 3 boxes" < <(line_of 72)
expect "boundary: 73 columns fails" 1 "line 1: 73 columns, limit is 72" < <(line_of 73)
# repeat <text> <count> : the text <count> times, then a newline.
repeat() {
  local i
  for ((i = 0; i < $2; i++)); do printf '%s' "$1"; done
  echo
}

expect "boundary: 36 Hangul = 72 columns passes" 0 "OK: 3 boxes" < <(repeat 가 36; row 3)
expect "boundary: 37 Hangul = 74 columns fails" 1 "line 1: 74 columns" < <(repeat 가 37; row 3)
expect "boundary: 36 fullwidth letters + 1 ASCII = 73 columns fails" 1 "line 1: 73 columns" < <(repeat Ａ 36 | tr -d '\n'; echo x; row 3)
expect "boundary: two boxes fails" 1 "diagram: 2 boxes" < <(row 2)
expect "boundary: nine boxes passes" 0 "OK: 9 boxes" < <(row 9)
expect "boundary: ten boxes fails" 1 "diagram: 10 boxes" < <(row 10)

expect "failure: box-drawing characters" 1 "U+250C" < <(printf '%s\n' '┌───┐ ┌───┐ ┌───┐' '│ A │ │ B │ │ C │' '└───┘ └───┘ └───┘')
expect "failure: tab character" 1 "line 4: character 2 is U+0009" < <(row 3; printf 'A\t-> B\n')
expect "failure: Unicode arrow" 1 "U+2192" < <(row 3; echo 'A → B')
expect "failure: DEL control character" 1 "line 4: character 2 is U+007F" < <(row 3; printf 'A\177B\n')

out="$("$checker" < <(row 3; echo 'A → B → C') || true)"
if [[ "$out" == "line 4: character 3 is U+2192, use ASCII symbols only" ]]; then
  echo "ok   failure: one report per line, for the first bad character"
else
  echo "FAIL one report per line: $out"
  failures=$((failures+1))
fi
expect "failure: misaligned corner is not a box" 1 "diagram: 2 boxes" < <(printf '%s\n' '+---+ +---+ +----+' '| A | | B | | C |' '+---+ +---+ +----+')

code=0; "$checker" a b >/dev/null 2>&1 || code=$?
if [[ "$code" == 2 ]]; then echo "ok   usage: two arguments exit 2"; else echo "FAIL usage: exit $code"; failures=$((failures+1)); fi
code=0; "$checker" "$(mktemp -d)/missing.txt" >/dev/null 2>&1 || code=$?
if [[ "$code" == 2 ]]; then echo "ok   usage: missing file exit 2"; else echo "FAIL missing file: exit $code"; failures=$((failures+1)); fi

[[ $failures -eq 0 ]]
