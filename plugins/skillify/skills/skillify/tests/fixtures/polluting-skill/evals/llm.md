# LLM eval

## Scenario 1 — fixture passes gates 1-9 but fails gate 10
- Input: skillify's gate-10 integration test invokes validate.sh on this fixture.
- Expected: validate.sh exits 1 with `tests pollute real runtime skill directories` after `ok: location`.
- Failure mode if procedure skipped: gate 10 silently accepts $HOME-writing tests, the recurrence prevention promise is broken.

## Scenario 2 — fixture's structure is otherwise compliant
- Input: validate.sh runs gates 1-9 on the fixture before reaching gate 10.
- Expected: each of gates 1-9 prints `ok:` because the fixture is otherwise structurally valid.
- Failure mode if procedure skipped: any earlier gate failure would mask the gate-10 demonstration.

## Scenario 3 — gate 10 skips fixtures inside other skills
- Input: validate.sh runs on the parent skill (skillify), whose tests/fixtures includes this polluting fixture.
- Expected: gate 10 skips paths under `*/fixtures/*` and does not flag the parent skill.
- Failure mode if procedure skipped: every skill that ships a polluting fixture gets blocked by its own gate, breaking dog-fooding.
