# Resolver eval — no-recommended-skill (fixture)

Compliant resolver body for the (D1)-fallback fixture.

## Positive triggers (must activate this skill)
1. skillify integration test injecting this fixture to verify the no-warning path.
2. Direct reference to the fixture name from the recommended-skill warning unit test.
3. Programmatic copy of this fixture into a candidate location.

## Negative triggers (must NOT activate)
1. Unrelated user prompts.
2. References to other fixtures (valid-skill, hedging-skill).
3. Casual mentions of recommended skills outside the skillify test context.
