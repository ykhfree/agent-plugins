# LLM eval — valid-skill (fixture)

Compliant fixture used by skillify's own tests. Exercises the structural eval
gate's three-scenario minimum.

## Scenario 1 — happy path
- Input: a SKILL.md authored from the (D1) fallback with no hedging.
- Expected: validator exits 0.
- Failure mode if procedure skipped: validator silently accepts unfilled placeholders.

## Scenario 2 — boundary: maximum description length
- Input: SKILL.md with a 1024-character description.
- Expected: validator exits 0.
- Failure mode if procedure skipped: off-by-one accepting a 1025-char description.

## Scenario 3 — boundary: minimum compliant body
- Input: SKILL.md with the bare-minimum required sections only.
- Expected: validator exits 0.
- Failure mode if procedure skipped: validator demands sections beyond the (D1) contract.
