# LLM eval — no-recommended-skill (fixture)

Compliant eval body for the (D1)-fallback fixture.

## Scenario 1 — no recommended sub-skill referenced
- Input: SKILL.md authored entirely from skillify's (D1) inline fallback.
- Expected: validator exits 0 with no WARN line on stderr.
- Failure mode if procedure skipped: warning fires for skills that do not depend on recommended sub-skills.

## Scenario 2 — recommended sub-skill referenced but absent at runtime
- Input: SKILL.md mentions a recommended sub-skill while it is not installed.
- Expected: validator exits 0 but emits a single WARN on stderr.
- Failure mode if procedure skipped: absence is treated as a hard failure, blocking valid skills.

## Scenario 3 — recommended sub-skill referenced and present
- Input: SKILL.md mentions a recommended sub-skill and it is installed.
- Expected: validator exits 0 with no warning.
- Failure mode if procedure skipped: false-positive warnings for correctly configured installs.
