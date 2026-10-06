#!/usr/bin/env bash
# Unit test: `mh.py gaps` filters Kotlin noise (Intrinsics calls, default getters), tags log guards
# and once-per-JVM initializers, applies scope and limit, and
# exits 0 (no gaps) / 1 (gaps) / 2 (bad input).
skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$skill_root/tests/lib/common.sh"

repo="$fixtures/sample-project"
report="$fixtures/sample-report/mutations.xml"

# 1) happy path: boundary mutant first, log-guard mutant last, two Intrinsics mutants and the three
#    data class getter mutants of Settings.kt removed.
expect 1 "$mh" gaps --repo "$repo" --module . --report "$report"
check 'len(d["gaps"]) == 2 and d["filtered"]["kotlin-intrinsics"] == 2 and d["filtered"]["kotlin-accessor"] == 3'
check 'd["gaps"][0]["line"] == 10 and d["gaps"][0]["mutator"] == "ConditionalsBoundaryMutator" and d["gaps"][0]["hints"] == []'
check 'd["gaps"][1]["line"] == 14 and d["gaps"][1]["hints"] == ["log-guard"]'
check 'd["gaps"][0]["path"] == "src/main/kotlin/sample/Discount.kt"'
check 'd["gaps"][0]["covering_test_count"] == 3 and "sample.DiscountTest#small order gets no discount" in d["gaps"][0]["covering_tests"]'

# 2) boundary: a scope that covers only line 10 drops the line-14 mutant.
cat > "$work/scope.json" <<'JSON'
{"base": "x", "modules": [{"dir": ".", "changed": {"src/main/kotlin/sample/Discount.kt": [[9, 10]]}, "target_classes": []}]}
JSON
expect 1 "$mh" gaps --repo "$repo" --module . --report "$report" --scope "$work/scope.json"
check 'len(d["gaps"]) == 1 and d["gaps"][0]["line"] == 10 and d["filtered"]["outside-scope"] == 1'

# 3) boundary: --limit keeps the top-ranked gap and counts the rest.
expect 1 "$mh" gaps --repo "$repo" --module . --report "$report" --limit 1
check 'len(d["gaps"]) == 1 and d["gaps"][0]["line"] == 10 and d["dropped_by_limit"] == 1'

# 4) boundary: a report whose sources are not in the repo. Only SURVIVED and NO_COVERAGE mutants
#    are gaps, Intrinsics calls in inner classes are filtered, and covering tests are deduplicated
#    and capped at 10 while the count keeps the full number.
covering=""
for i in $(seq 1 12) 1; do
  covering+="c.CacheTest.[engine:junit-jupiter]/[class:c.CacheTest]/[method:case $i()]|"
done
cat > "$work/nosource.xml" <<XML
<mutations partial="true">
<mutation status='SURVIVED'><sourceFile>Cache.kt</sourceFile><mutatedClass>c.Cache</mutatedClass><mutatedMethod>get</mutatedMethod><lineNumber>5</lineNumber><mutator>org.pitest.ConditionalsBoundaryMutator</mutator><coveringTests>${covering%|}</coveringTests><description>boundary</description></mutation>
<mutation status='NO_COVERAGE'><sourceFile>Cache.kt</sourceFile><mutatedClass>c.Cache\$Companion\$load\$1</mutatedClass><mutatedMethod>invoke</mutatedMethod><lineNumber>9</lineNumber><mutator>org.pitest.NullReturnValsMutator</mutator><description>no coverage</description></mutation>
<mutation status='SURVIVED'><sourceFile>Cache.kt</sourceFile><mutatedClass>c.Cache\$get\$1</mutatedClass><mutatedMethod>invoke</mutatedMethod><lineNumber>6</lineNumber><mutator>org.pitest.VoidMethodCallMutator</mutator><description>removed call to kotlin/jvm/internal/Intrinsics::checkNotNullParameter</description></mutation>
<mutation status='TIMED_OUT'><sourceFile>Cache.kt</sourceFile><mutatedClass>c.Cache</mutatedClass><mutatedMethod>get</mutatedMethod><lineNumber>7</lineNumber><mutator>org.pitest.NegateConditionalsMutator</mutator><description>timed out</description></mutation>
<mutation status='KILLED'><sourceFile>Cache.kt</sourceFile><mutatedClass>c.Cache</mutatedClass><mutatedMethod>get</mutatedMethod><lineNumber>8</lineNumber><mutator>org.pitest.NegateConditionalsMutator</mutator><description>killed</description></mutation>
</mutations>
XML
expect 1 "$mh" gaps --repo "$work" --module . --report "$work/nosource.xml"
check '[g["description"] for g in d["gaps"]] == ["boundary", "no coverage"] and d["filtered"]["kotlin-intrinsics"] == 1'
check 'all(g["path"] is None and g["source_file"] == "Cache.kt" for g in d["gaps"])'
check 'd["gaps"][0]["covering_test_count"] == 12 and len(d["gaps"][0]["covering_tests"]) == 10'

# 5) excluded tests recorded by `run` are reported next to the gaps.
mkdir -p "$work/report"
cp "$report" "$work/report/mutations.xml"
echo '{"excluded_tests": ["*RedisTest"]}' > "$work/report/mh-run.json"
expect 1 "$mh" gaps --repo "$repo" --module . --report "$work/report/mutations.xml"
check 'd["excluded_tests"] == ["*RedisTest"]'

# 6) no gaps: every mutant killed gives exit 0 and an empty list.
sed -e "s/status='SURVIVED'/status='KILLED'/g" "$report" > "$work/killed.xml"
expect 0 "$mh" gaps --repo "$repo" --module . --report "$work/killed.xml"
check 'd["gaps"] == []'

# Synthetic module and report for the hint and accessor rules below.
hint_repo="$work/hint"
mkdir -p "$hint_repo/src/main/kotlin/h"
cat > "$hint_repo/src/main/kotlin/h/Pool.kt" <<'KT'
package h

class Pool(val size: Int) {
    val custom: Int get() = size * 2

    companion object {
        val shared: Any by lazy {
            Any()
        }
    }

    fun startMonitoring() = Runnable { }
}
KT
mutation() {  # mutation <class> <method> <line> <mutator> <description>
  printf "<mutation detected='false' status='SURVIVED'><sourceFile>Pool.kt</sourceFile><mutatedClass>%s</mutatedClass><mutatedMethod>%s</mutatedMethod><methodDescription>()V</methodDescription><lineNumber>%s</lineNumber><mutator>org.pitest.%s</mutator><indexes><index>1</index></indexes><killingTests></killingTests><coveringTests></coveringTests><description>%s</description></mutation>\n" "$@"
}
{
  echo '<mutations partial="true">'
  mutation 'h.Pool$Companion$shared$2' invoke 7 NullReturnValsMutator 'kotlin 1 lazy'
  mutation 'h.Pool' 'shared_delegate$lambda$1' 8 NullReturnValsMutator 'kotlin 2 lazy'
  mutation 'h.Pool' '&lt;clinit&gt;' 7 VoidMethodCallMutator 'static init'
  mutation 'h.Pool$startMonitoring$1' run 12 VoidMethodCallMutator 'plain lambda'
  mutation 'h.Pool' getSize 3 PrimitiveReturnsMutator 'default getter'
  mutation 'h.Pool' getCustom 4 PrimitiveReturnsMutator 'custom getter'
  echo '</mutations>'
} > "$work/hint.xml"

# 7) boundary: lazy initializers (Kotlin 1.x class and 2.x method names) and <clinit> get the
#    once-per-jvm hint; a plain lambda in a function does not.
expect 1 "$mh" gaps --repo "$hint_repo" --module . --report "$work/hint.xml"
check '{g["description"]: g["hints"] for g in d["gaps"]} == {"kotlin 1 lazy": ["once-per-jvm"], "kotlin 2 lazy": ["once-per-jvm"], "static init": ["once-per-jvm"], "plain lambda": [], "custom getter": []}'

# 8) boundary: the default getter of `val size` is filtered; the custom getter `get() = size * 2` is kept.
check 'd["filtered"]["kotlin-accessor"] == 1 and "default getter" not in [g["description"] for g in d["gaps"]]'

# 9) failure: missing report.
expect 2 "$mh" gaps --repo "$repo" --module . --report "$work/none.xml"

# 10) failure: malformed XML.
printf '<mutations><mutation' > "$work/bad.xml"
expect 2 "$mh" gaps --repo "$repo" --module . --report "$work/bad.xml"

echo "gaps_test: ok"
