#!/usr/bin/env bash
# Integration test: scope + gaps on a git copy of the fixture project. Only the mutant on the
# changed line remains in scope. Uses the PIT report generated from this fixture (no Gradle here).
skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$skill_root/tests/lib/common.sh"

repo="$work/sample"
cp -R "$fixtures/sample-project" "$repo"
new_repo "$repo"
commit_all "$repo" base
src="$repo/src/main/kotlin/sample/Discount.kt"

# Change the comment above the threshold line and the threshold line itself (lines 9-10).
python3 - "$src" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("// Orders of 10,000 or more", "// Orders from 10,000")
s = s.replace("amount >= 10_000", "amount >= 10000")
open(p, "w").write(s)
PY

expect 0 "$mh" scope --repo "$repo" --base HEAD
printf '%s' "$out" > "$work/scope.json"
check 'd["modules"][0]["dir"] == "." and d["modules"][0]["changed"] == {"src/main/kotlin/sample/Discount.kt": [[9, 10]]}'
check '"sample.Discount*" in d["modules"][0]["target_classes"]'

expect 1 "$mh" gaps --repo "$repo" --module . --report "$fixtures/sample-report/mutations.xml" --scope "$work/scope.json"
check '[(g["line"], g["mutator"]) for g in d["gaps"]] == [(10, "ConditionalsBoundaryMutator")]'
check 'd["filtered"] == {"kotlin-intrinsics": 2, "kotlin-accessor": 3, "outside-scope": 1}'

echo "sample_project_scope_gaps_test: ok"
