#!/usr/bin/env bash
# Unit test: quote_check.py locates quotes, returns the ±15-line section, and
# exits 0 (all found) / 1 (fabricated or file_missing) / 2 (bad input).
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
qc="$skill_root/scripts/quote_check.py"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"

# 40 numbered lines; line 20 holds a threshold, lines 30-32 a wrapped string.
python3 - <<'PY'
lines = [f"line {i}" for i in range(1, 41)]
lines[19] = "    if score >= THRESHOLD:"
lines[29] = '    msg = ("the quick'
lines[30] = ""
lines[31] = '    brown fox")'
open("code.py", "w").write("\n".join(lines) + "\n")
PY

# run <expected-exit> <json>: stores stdout in $out, fails on a wrong exit code.
run() {
  local want="$1" got=0
  out="$(printf '%s' "$2" | "$qc" - 2>/dev/null)" || got=$?
  if [[ "$got" != "$want" ]]; then
    echo "expected exit $want, got $got for input: $2" >&2
    exit 1
  fi
}
# check <python expression over d (the parsed output)>
check() {
  if ! printf '%s' "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if ($1) else 1)"; then
    echo "assertion failed: $1" >&2
    echo "output: $out" >&2
    exit 1
  fi
}

# 1) happy path: found, exact line range, section = lines 5..35 (20 ± 15).
run 0 '[{"claim": "uses >=", "file": "code.py", "quote": "if score >= THRESHOLD:"}]'
check 'd["claims"][0]["verdict"] == "found" and d["claims"][0]["lines"] == "20-20"'
check 'd["claims"][0]["section"].splitlines()[0] == "line 5" and d["claims"][0]["section"].splitlines()[-1] == "line 35"'
check 'len(d["claims"][0]["section"].splitlines()) == 31'

# 2) boundary: a quote across a blank line and a wrap, with curly quotes, spans 30-32;
#    the section near the end of the file is clipped at line 40.
run 0 '[{"claim": "c", "file": "code.py", "quote": "msg = (“the quick brown fox”)"}]'
check 'd["claims"][0]["lines"] == "30-32" and d["claims"][0]["section"].splitlines()[-1] == "line 40"'

# 3) boundary: a quote on line 1 clips the section at the top (lines 1..16).
run 0 '[{"claim": "c", "file": "code.py", "quote": "line 1"}]'
check 'd["claims"][0]["lines"] == "1-1" and len(d["claims"][0]["section"].splitlines()) == 16'

# 4) failure: a misquote (> instead of >=) is fabricated and exits 1; order is kept.
run 1 '[{"claim": "a", "file": "code.py", "quote": "line 2"}, {"claim": "b", "file": "code.py", "quote": "if score > THRESHOLD:"}, {"claim": "c", "file": "nope.py", "quote": "x"}, {"claim": "e", "file": "code.py", "quote": "  "}]'
check '[c["verdict"] for c in d["claims"]] == ["found", "fabricated", "file_missing", "fabricated"]'
check '"section" not in d["claims"][1] and "lines" not in d["claims"][2]'

# 5) failure: bad input exits 2 with no stdout.
run 2 'not json'
[[ -z "$out" ]] || { echo "expected no stdout on bad input" >&2; exit 1; }
run 2 '[{"claim": "a", "file": "code.py"}]'
run 2 '{"claim": "a", "file": "code.py", "quote": "x"}'

# 6) the claims file can be passed as an argument instead of stdin.
printf '%s' '[{"claim": "a", "file": "code.py", "quote": "line 7"}]' > claims.json
out="$("$qc" claims.json)"
check 'd["claims"][0]["lines"] == "7-7"'

echo "quote_check_test ok"
