#!/usr/bin/env bash
# Integration test: both scripts on the fixtures, and SKILL.md against verdict.py.
# 1) Every tests/fixtures/jev-output/<command>.<action>.json gets that action from verdict.py.
# 2) The commands under "### Jev decides" in SKILL.md are exactly those with a decide fixture,
#    and every command under "### Commands" is one verdict.py knows.
# 3) scan_secrets.py passes the sample tree, then catches a key added to a copy of it.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
v="$skill_root/scripts/verdict.py"
scan="$skill_root/scripts/scan_secrets.py"
fixtures="$skill_root/tests/fixtures"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# 1) fixtures
count=0
for f in "$fixtures"/jev-output/*.json; do
  name="$(basename "$f" .json)"
  command="${name%%.*}"
  action="${name#*.}"
  want=0; [[ "$action" == advise ]] && want=1
  got=0
  "$v" "$command" < "$f" > /dev/null || got=$?
  [[ "$got" == "$want" ]] || { echo "$name: expected exit $want, got $got" >&2; exit 1; }
  count=$((count + 1))
done
[[ "$count" -ge 10 ]] || { echo "expected at least 10 fixtures, found $count" >&2; exit 1; }

# 2) SKILL.md and the script agree
python3 - "$skill_root" <<'PY'
import importlib.util, re, sys
from pathlib import Path

root = Path(sys.argv[1])
text = (root / "SKILL.md").read_text()

def section(title):
    m = re.search(rf"^### {title}\n(.*?)(?=^#{{2,3}} |\Z)", text, re.M | re.S)
    assert m, f"no section {title}"
    return m.group(1)

decides = set(re.findall(r"^- `(\w+)`:", section("Jev decides"), re.M))
with_decide_fixture = {p.name.split(".")[0] for p in (root / "tests/fixtures/jev-output").glob("*.decide.json")}
assert decides == with_decide_fixture, (decides, with_decide_fixture)

spec = importlib.util.spec_from_file_location("verdict", root / "scripts/verdict.py")
verdict = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verdict)
listed = set(re.findall(r"`(?:<search hits> \| )?jev (\w+)", section("Commands")))
assert listed == set(verdict.COMMANDS), (listed, verdict.COMMANDS)
PY

# 3) secret scan on the sample tree and on a copy with a key added
"$scan" "$fixtures/sample-tree" > /dev/null || { echo "sample tree must be clean" >&2; exit 1; }
cp -R "$fixtures/sample-tree" "$work/tree"
printf 'LOG_UPLOAD_TOKEN=%s\n' "$(printf 'x%.0s' {1..24})" >> "$work/tree/logs/app.txt"
got=0
out="$("$scan" "$work/tree")" || got=$?
[[ "$got" == 1 ]] || { echo "expected exit 1 after adding a token, got $got" >&2; exit 1; }
[[ "$out" == "$work/tree/logs/app.txt:4: secret-assignment" ]] || { echo "unexpected output: $out" >&2; exit 1; }

echo "fixtures_test: ok ($count fixtures)"
