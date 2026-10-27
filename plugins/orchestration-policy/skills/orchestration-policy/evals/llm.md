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
