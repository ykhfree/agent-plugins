#!/usr/bin/env bash
# Integration test: SKILL.md and route.py agree, and a synthetic task replays correctly.
# 1) Every row of the "Step facts", "Search facts", and "Advisor events" tables in SKILL.md
#    gives the route that its Route column names, and every fact the script knows has a row.
# 2) tests/fixtures/task-log.tsv replays one task, including a 4th advisor consult that
#    the budget stops.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"

python3 - "$skill_root" <<'PY'
import importlib.util, json, re, subprocess, sys
from pathlib import Path

root = Path(sys.argv[1])
script = root / "scripts/route.py"
text = (root / "SKILL.md").read_text()

def rows(title):
    m = re.search(rf"^### {title}\n(.*?)(?=^#{{2,3}} |\Z)", text, re.M | re.S)
    assert m, f"no section {title}"
    out = []
    for line in m.group(1).splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if line.startswith("|") and not set(cells[0]) <= set("-") and cells[0] not in ("Rule", "Facts"):
            out.append(cells)
    assert out, f"no rows in {title}"
    return out

def route(*args):
    p = subprocess.run([sys.executable, str(script), *args], capture_output=True, text=True)
    assert p.returncode in (0, 1), (args, p.returncode, p.stderr)
    return json.loads(p.stdout)

def names(cell):
    return [] if cell == "none" else [w for span in re.findall(r"`([^`]+)`", cell) for w in span.split()]

spec = importlib.util.spec_from_file_location("route", script)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

seen = set()
for rule, facts, _, cell in rows("Step facts"):
    facts = names(facts)
    seen |= set(facts)
    got = route("step", *facts)
    assert got["rule"] == int(rule) and got["route"] == names(cell), (facts, got, cell)
assert seen == set(mod.STEP_FACTS) | set(mod.MODIFIERS), seen

seen = set()
for facts, _, cell in rows("Search facts"):
    (fact,) = names(facts)
    seen.add(fact)
    assert route("search", fact)["route"] == names(cell), fact
assert seen == set(mod.SEARCH), seen

seen = set()
for facts, _, cell in rows("Advisor events"):
    (event,) = names(facts)
    seen.add(event)
    assert route("advisor", event, "--consults", "0")["route"] == names(cell), event
assert seen == set(mod.ADVISOR_ALWAYS + mod.ADVISOR_NEVER), seen
assert f"At most {mod.ADVISOR_BUDGET} consults per task" in text

# 2) replay
steps = 0
for line in (root / "tests/fixtures/task-log.tsv").read_text().splitlines():
    if not line or line.startswith("#"):
        continue
    kind, args, want_exit, want_route = line.split("\t")
    p = subprocess.run([sys.executable, str(script), kind, *args.split()], capture_output=True, text=True)
    assert p.returncode == int(want_exit), (line, p.returncode, p.stderr)
    assert json.loads(p.stdout)["route"] == want_route.split(","), (line, p.stdout)
    steps += 1
assert steps == 10, steps
print(f"tables_test: ok ({steps} replayed steps)")
PY
