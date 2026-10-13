# LLM eval — hedging-skill (fixture)

Compliant eval body so this fixture only fails the validator on hedging,
not on eval structure. The hedging language under test lives in the SKILL.md.

## Scenario 1 — hedging in body
- Input: SKILL.md body contains a Korean hedging word.
- Expected: validator exits 1 with hedging error.
- Failure mode if procedure skipped: hedging slips past unchecked.

## Scenario 2 — hedging in body (English)
- Input: SKILL.md body contains an English hedging word.
- Expected: validator exits 1 with hedging error.
- Failure mode if procedure skipped: only Korean hedging is caught.

## Scenario 3 — hedging masked by code span
- Input: SKILL.md uses a hedging word inside a backtick code span.
- Expected: validator exits 0 (code spans are stripped before checking).
- Failure mode if procedure skipped: documenting bad examples becomes impossible.
