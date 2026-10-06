#!/usr/bin/env bash
# Unit test: `mh.py scope` maps changed main Kotlin lines to modules and PIT target classes, and
# exits 0 (changes) / 3 (no main Kotlin change) / 2 (bad input).
skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$skill_root/tests/lib/common.sh"

repo="$work/repo"
new_repo "$repo"
mkdir -p "$repo/core/src/main/kotlin/a" "$repo/core/src/test/kotlin/a" "$repo/src/main/kotlin/b"
printf 'package a\n\nclass Foo {\n    fun x() = 1\n}\n\ndata class Bar(val v: Int)\n\nfun top() = 2\n' \
  > "$repo/core/src/main/kotlin/a/Foo.kt"
printf 'package a\n\nclass FooTest\n' > "$repo/core/src/test/kotlin/a/FooTest.kt"
printf 'package b\n\nobject Gone\n' > "$repo/src/main/kotlin/b/Gone.kt"
commit_all "$repo" base

# 1) happy path: one changed line in a module file gives its range and every top-level type.
sed -i.bak 's/fun x() = 1/fun x() = 3/' "$repo/core/src/main/kotlin/a/Foo.kt" && rm "$repo/core/src/main/kotlin/a/Foo.kt.bak"
expect 0 "$mh" scope --repo "$repo" --base HEAD
check 'len(d["modules"]) == 1 and d["modules"][0]["dir"] == "core"'
check 'd["modules"][0]["changed"] == {"core/src/main/kotlin/a/Foo.kt": [[4, 4]]}'
check 'd["modules"][0]["target_classes"] == ["a.Bar*", "a.Foo*", "a.FooKt*"]'

# 2) boundary: an untracked file in the root module counts as fully changed.
printf 'package b\n\nclass New\n' > "$repo/src/main/kotlin/b/New.kt"
expect 0 "$mh" scope --repo "$repo" --base HEAD
check '[m["dir"] for m in d["modules"]] == [".", "core"]'
check 'd["modules"][0]["changed"] == {"src/main/kotlin/b/New.kt": [[1, 3]]}'
check 'd["modules"][0]["target_classes"] == ["b.New*", "b.NewKt*"]'

# 3) boundary: test-only changes and a deleted main file give exit 3.
git -C "$repo" checkout -q -- . && rm "$repo/src/main/kotlin/b/New.kt"
printf 'package a\n\nclass FooTest2\n' > "$repo/core/src/test/kotlin/a/FooTest.kt"
git -C "$repo" rm -q "$repo/src/main/kotlin/b/Gone.kt"
expect 3 "$mh" scope --repo "$repo" --base HEAD
check 'd["modules"] == []'

# 4) failure: unknown base ref.
expect 2 "$mh" scope --repo "$repo" --base no-such-ref

# 5) failure: not a git repository.
mkdir -p "$work/plain"
expect 2 "$mh" scope --repo "$work/plain" --base HEAD

echo "scope_test: ok"
