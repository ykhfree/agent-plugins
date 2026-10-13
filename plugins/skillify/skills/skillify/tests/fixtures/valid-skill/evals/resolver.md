# Resolver eval — valid-skill (fixture)

Compliant fixture used by skillify's own tests. Exercises the resolver gate's
positive/negative section requirement.

## Positive triggers (must activate this skill)
1. Direct reference to the fixture name in skillify's own tests.
2. Programmatic copy of this fixture into a candidate location for the location-gate test.
3. Programmatic copy of this fixture into a tmp dir for the frontmatter test.

## Negative triggers (must NOT activate)
1. Unrelated user prompts with no skillify keyword.
2. References to other fixtures (e.g., hedging-skill, no-recommended-skill).
3. Casual mentions of "valid skill" outside skillify's test context.
