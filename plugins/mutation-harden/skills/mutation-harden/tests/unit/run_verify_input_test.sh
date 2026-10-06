#!/usr/bin/env bash
# Unit test: `mh.py run` and `mh.py verify` reject bad input with exit 2, and verify stops at the
# first failed gate with exit 1. A stub gradlew stands in for Gradle; the e2e test runs the real one.
skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$skill_root/tests/lib/common.sh"

repo="$work/repo"
new_repo "$repo"
mkdir -p "$repo/src/main/kotlin/sample"
cp "$fixtures/sample-project/src/main/kotlin/sample/Discount.kt" "$repo/src/main/kotlin/sample/"
commit_all "$repo" base
expect 1 "$mh" gaps --repo "$repo" --module . --report "$fixtures/sample-report/mutations.xml"
printf '%s' "$out" > "$work/gaps.json"
id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["gaps"][0]["id"])' "$work/gaps.json")"
expect 0 "$mh" fingerprint --repo "$repo"
fp="$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["fingerprint"])')"

verify() {
  "$mh" verify --repo "$repo" --module . --gaps "$work/gaps.json" --fingerprint "$1" \
    --test-class sample.DiscountTest --test-method "$2" --mutant "$3"
}

# 1) failure: run without gradlew.
expect 2 "$mh" run --repo "$repo" --module . --classes 'sample.*'

# A stub gradlew that always fails.
printf '#!/bin/sh\nexit 1\n' > "$repo/gradlew" && chmod +x "$repo/gradlew"

# 2) failure: run with an empty class list.
expect 2 "$mh" run --repo "$repo" --module . --classes ' , '

# 3) failure: verify with a mutant id that is not in the gaps file.
expect 2 verify "$fp" t m-0000000000

# 4) boundary: a changed fingerprint fails the first gate before Gradle runs.
expect 1 verify "different" t "$id"
check 'd["gates"] == {"main-code-unchanged": False}'

# 5) boundary: a failing test run stops at the test gate.
expect 1 verify "$fp" t "$id"
check 'd["gates"] == {"main-code-unchanged": True, "test-passes-run-1": False}'

# 6) failure: run on a missing module directory.
expect 2 "$mh" run --repo "$repo" --module nope --classes 'sample.*'

echo "run_verify_input_test: ok"
