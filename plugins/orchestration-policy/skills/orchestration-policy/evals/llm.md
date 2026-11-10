# LLM eval

## Scenario 1 — an exact edit that looks like boilerplate
- Input: "오케스트레이션 정책 적용해. config.yaml의 timeout을 30에서 60으로 바꿔줘." Claude has
  already read `config.yaml`.
- Expected: Claude judges `exact-edit` and `fully-specified`, runs `scripts/route.py step exact-edit
  fully-specified`, gets rule 1 (`main`), and makes the edit itself.
- Failure mode if procedure skipped: Claude matches "only needs to be typed out" first and spawns
  `fast-worker` for a one-line edit, which costs more than the edit.

## Scenario 2 — a fourth advisor consult
- Input: during a long migration task under the policy, the same test failure returns after a third
  fix. Claude has consulted the advisor 3 times in this task.
- Expected: Claude runs `scripts/route.py advisor repeat-error --consults 3`, gets exit 1 and route
  `user`, and asks the user before a 4th consult.
- Failure mode if procedure skipped: Claude loses count of earlier consults and calls the advisor a
  4th and 5th time without asking.

## Scenario 3 — a schema choice with open options
- Input: "정책 적용해서, 주문 테이블을 이벤트 소싱으로 바꿀지 상태 테이블로 둘지 정해줘."
- Expected: Claude judges `costly-decision options-open`, runs `route.py step costly-decision
  options-open`, sends the design to `deep-reasoner`, spawns a `critic` only if two or more options
  have no clear winner, and consults the advisor before it commits.
- Failure mode if procedure skipped: Claude judges the task `undecided` (rule 3) and commits to the
  deep-reasoner design without the advisor consult that a costly-to-revert decision needs.

## Scenario 4 — bulk work that needs the conversation
- Input: under the policy, after a long session, the user and Claude agreed that the legacy
  `billing/` module must not change. The user asks: "새 API를 쓰는 호출부 40곳이 맞게 바뀌었는지
  확인해줘." The task goes on after this check.
- Expected: Claude judges `context-bound-bulk` (the `billing/` constraint lives only in the
  conversation, 40 files are bulk output, and the session goes on), runs `route.py step
  context-bound-bulk`, gets rule 4 (`fork`), and forks its session. The fork returns a short list
  of wrong call sites.
- Contrast: "호출부 40곳에서 `oldName`을 `newName`으로 바꿔줘" fails fact (a), because a brief
  carries all of it. The step goes to rule 6 (`fast-worker`).
- Failure mode if procedure skipped: Claude reads all 40 files into its own context, or sends a
  fresh subagent a brief that drops the `billing/` constraint.

## Scenario 5 — a long test log that needs no conversation context
- Input: under the policy, the user asks: "전체 테스트 돌려서 실패한 것만 알려줘." The suite prints
  thousands of lines. Nothing in the conversation changes which failures matter.
- Expected: Claude judges `bulk-output` (large log, a brief carries the command and the facts to
  return, and each failure can be checked by test name), runs `route.py step bulk-output`, gets
  rule 5 (`log-reader`), and gives it the test command. It reports each failing test with its first
  error line. Claude opens only the failures it will fix.
- Contrast: if the session agreed on several rules about which failures matter (known flaky tests,
  modules the user froze, a migration half done), and a brief cannot carry them all, fact (b)
  fails. The step is `context-bound-bulk` (rule 4, `fork`).
- Failure mode if procedure skipped: Claude runs the suite in its own session, and the full log
  fills the context of the most expensive model.
