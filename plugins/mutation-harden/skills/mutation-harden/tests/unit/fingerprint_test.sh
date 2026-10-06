#!/usr/bin/env bash
# Unit test: `mh.py fingerprint` changes when any src/main file changes and only then.
skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$skill_root/tests/lib/common.sh"

repo="$work/repo"
new_repo "$repo"
mkdir -p "$repo/m/src/main/kotlin" "$repo/m/src/test/kotlin"
echo 'class A' > "$repo/m/src/main/kotlin/A.kt"
echo 'class ATest' > "$repo/m/src/test/kotlin/ATest.kt"
commit_all "$repo" base

fp() { expect 0 "$mh" fingerprint --repo "$repo"; printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["fingerprint"])'; }

# 1) happy path: the same tree gives the same hash.
base="$(fp)"
[[ "$(fp)" == "$base" ]] || { echo "fingerprint is not stable" >&2; exit 1; }

# 2) boundary: a test-only change keeps the hash.
echo 'class ATest2' > "$repo/m/src/test/kotlin/ATest.kt"
[[ "$(fp)" == "$base" ]] || { echo "test change altered the fingerprint" >&2; exit 1; }

# 3) boundary: an untracked main file changes the hash.
echo 'class B' > "$repo/m/src/main/kotlin/B.kt"
[[ "$(fp)" != "$base" ]] || { echo "untracked main file not detected" >&2; exit 1; }
rm "$repo/m/src/main/kotlin/B.kt"

# 4) failure path for the gate: an edited main file changes the hash.
echo 'class A2' > "$repo/m/src/main/kotlin/A.kt"
[[ "$(fp)" != "$base" ]] || { echo "main edit not detected" >&2; exit 1; }

# 5) failure: not a git repository.
mkdir -p "$work/plain"
expect 2 "$mh" fingerprint --repo "$work/plain"

echo "fingerprint_test: ok"
