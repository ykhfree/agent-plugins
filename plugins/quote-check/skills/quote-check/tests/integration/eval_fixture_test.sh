#!/usr/bin/env bash
# Integration test: quote_check.py on a small sample repository with three claims.
# Claim 1 quotes a line whose meaning depends on a constant defined more than
# 15 lines away, so the returned section cannot settle the claim.
# Claim 2 is a plain found quote. Claim 3 is a one-character misquote.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
qc="$skill_root/scripts/quote_check.py"
cd "$skill_root/tests/fixtures/sample-repo"

got=0
out="$("$qc" claims.json)" || got=$?
[[ "$got" == 1 ]] || { echo "expected exit 1 (one misquote), got $got" >&2; exit 1; }

printf '%s' "$out" | python3 -c '
import json, sys
d = json.load(sys.stdin)["claims"]
assert [c["verdict"] for c in d] == ["found", "found", "fabricated"], d
# Claim 1: the quote is found, but the section does not define hi (0.7), so the
# script hands over text that cannot settle the claim instead of a verdict.
c1 = d[0]
assert c1["lines"] == "49-49", c1["lines"]
assert "noise\"] >= hi" in c1["section"]
assert "UNSURE_BAND = (0.3, 0.7)" not in c1["section"]
assert "UNSURE_BAND = (0.3, 0.7)" in open("gate.py").read()
# no field states whether a claim is true
assert all(set(c) <= {"claim", "file", "verdict", "lines", "section"} for c in d)
# Claim 2: section around store.py line 23
assert d[1]["lines"] == "23-23", d[1]["lines"]
'
echo "eval_fixture_test ok"
