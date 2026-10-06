#!/usr/bin/env bash
# E2E test: real Gradle + PIT on a git copy of the fixture project.
# A feature commit touches the 10,000 threshold. The weak suite misses the boundary mutant.
# verify rejects a test without an assertion, accepts a test that kills the mutant,
# and rejects any run after main code changed. Needs network access when $HOME/.gradle is empty.
skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$skill_root/tests/lib/common.sh"
export GRADLE_OPTS="-Dorg.gradle.daemon=false"
# Gradle reads the Java user.home property, not $HOME. Pin its cache to $HOME so an isolated
# HOME gets an empty cache instead of the operator's real one.
export GRADLE_USER_HOME="$HOME/.gradle"

repo="$work/sample"
cp -R "$fixtures/sample-project" "$repo"
new_repo "$repo"
commit_all "$repo" base
src="$repo/src/main/kotlin/sample/Discount.kt"
test_src="$repo/src/test/kotlin/sample/DiscountTest.kt"
sed -i.bak 's/amount >= 10_000/amount >= 10000/' "$src" && rm "$src.bak"
commit_all "$repo" feature

# add_test <name> <body>: appends a test method to DiscountTest.
add_test() {
  python3 - "$test_src" "$1" "$2" <<'PY'
import sys
path, name, body = sys.argv[1:]
src = open(path).read().rstrip()
assert src.endswith("}")
method = f"\n    @Test\n    fun `{name}`() {{\n        {body}\n    }}\n"
open(path, "w").write(src[:-1].rstrip() + "\n" + method + "}\n")
PY
}

expect 0 "$mh" fingerprint --repo "$repo"
fp="$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["fingerprint"])')"

expect 0 "$mh" scope --repo "$repo" --base HEAD~1
printf '%s' "$out" > "$work/scope.json"
classes="$(python3 -c 'import json,sys; print(",".join(json.load(open(sys.argv[1]))["modules"][0]["target_classes"]))' "$work/scope.json")"

expect 0 "$mh" run --repo "$repo" --module . --classes "$classes"
check 'd["gradle_exit"] == 0'
check 'd["report"].endswith("build/reports/pitest/mutations.xml")'

# The weak suite lets the boundary mutant on the changed line survive.
expect 1 "$mh" gaps --repo "$repo" --module . --scope "$work/scope.json"
printf '%s' "$out" > "$work/gaps.json"
check '[(g["line"], g["mutator"]) for g in d["gaps"]] == [(10, "ConditionalsBoundaryMutator")]'
id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["gaps"][0]["id"])' "$work/gaps.json")"

verify() {
  "$mh" verify --repo "$repo" --module . --gaps "$work/gaps.json" --fingerprint "$fp" \
    --test-class sample.DiscountTest --test-method "$1" --mutant "$id"
}

# A test without an assertion passes, but it does not kill the mutant: rejected.
add_test "boundary order runs" "Discount().apply(10_000)"
expect 1 verify "boundary order runs"
check 'd["gates"]["test-passes-run-2"] and not d["gates"]["new-test-kills-every-mutant"]'
check 'list(d["mutants"].values())[0]["status"] == "SURVIVED"'

# A test that pins the boundary kills the mutant: accepted.
add_test "order of exactly ten thousand gets ten percent off" "kotlin.test.assertEquals(9_000, Discount().apply(10_000))"
expect 0 verify "order of exactly ten thousand gets ten percent off"
check 'd["gates"]["new-test-kills-every-mutant"] and list(d["mutants"].values())[0]["status"] == "KILLED"'

# Changing main code to make a test pass is rejected before Gradle runs.
sed -i.bak 's/amount >= 10000/amount > 9999/' "$src" && rm "$src.bak"
expect 1 verify "order of exactly ten thousand gets ten percent off"
check 'd["gates"] == {"main-code-unchanged": False}'

echo "pit_roundtrip_test: ok"
