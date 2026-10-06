# LLM eval

Each scenario runs the skill in a Claude Code session. The expected behavior lists what must be true
when the session ends. The failure mode names what goes wrong when the model skips the procedure.

## Scenario 1 — Boundary gap on a feature branch
- Input: in a git copy of `tests/fixtures/sample-project`, commit a change to line 10 of `Discount.kt`,
  then ask "이 브랜치 변경분에 뮤테이션 테스트 돌려서 테스트 헛점 보강해줘".
- Expected: the model runs `fingerprint`, `scope --base HEAD~1`, `run`, and `gaps`. It shows the verdict
  table and asks the user before it edits any test file. After approval, it writes one test in
  `DiscountTest.kt` that asserts `apply(10_000) == 9_000`, `verify` exits 0, and `git status` shows no
  change under `src/main/`. The report lists the boundary mutant as `write-test` with the test name.
- Failure mode if procedure skipped: the model edits test files before the user approves the gap list, or
  it reads the code and writes tests by guess. It reports
  "coverage improved" with no PIT evidence, or it writes a test without an assertion that kills nothing.

## Scenario 2 — Log-guard and Kotlin noise are not turned into tests
- Input: same fixture, ask "sample 패키지 전체에 PIT 돌리고 살아남은 뮤턴트 전부 정리해줘".
- Expected: `gaps` drops the two `Intrinsics::checkNotNull` mutants (`filtered.kotlin-intrinsics == 2`)
  and the three `Settings` data class getter mutants (`filtered.kotlin-accessor == 3`).
  The line-14 mutant carries the `log-guard` hint and gets `skipped-equivalent` with a reason in the
  report. The model writes a test only for the line-10 boundary mutant.
- Failure mode if procedure skipped: the model writes tests that assert log output or null checks that
  Kotlin generated. Those tests are brittle and test nothing that a caller sees.

## Scenario 3 — Suspected bug instead of a locking test
- Input: change line 10 of `Discount.kt` to `amount > 10_000` while the comment still says
  "Orders of 10,000 or more get 10 percent off". Commit it, then ask "변경분 뮤테이션 테스트 해줘".
- Expected: the boundary mutant (`>` to `>=`) survives. The model sees that the mutant matches the
  comment, gives the verdict `suspected-bug`, writes no test for it, and asks the user which behavior is
  right. No file under `src/main/` changes.
- Failure mode if procedure skipped: the model writes a test that asserts `apply(10_000) == 10_000`. That
  test locks the bug in, and the next correct fix breaks it.
