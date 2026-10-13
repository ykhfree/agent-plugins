# Resolver eval

## Positive triggers (must activate this skill)
1. skillify's gate-10 integration test passing this fixture path to validate.sh.
2. Explicit reference to the `polluting-skill` fixture name.
3. Programmatic copy of this fixture into a candidate location for gate testing.

## Negative triggers (must NOT activate)
1. Unrelated user prompts.
2. References to other skills.
3. Casual mentions outside the integration test context.
