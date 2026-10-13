# Resolver eval — hedging-skill (fixture)

Compliant resolver body so this fixture only fails the validator on hedging
language in SKILL.md, not on eval structure.

## Positive triggers (must activate this skill)
1. skillify integration test injecting this fixture into the validator.
2. Direct reference to the fixture name from skillify's hedging unit test.
3. Programmatic copy of this fixture into a candidate location.

## Negative triggers (must NOT activate)
1. Unrelated user prompts.
2. References to other fixtures (valid-skill, no-recommended-skill).
3. Casual mentions of hedging outside the skillify test context.
