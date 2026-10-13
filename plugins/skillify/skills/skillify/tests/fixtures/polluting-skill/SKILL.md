---
name: polluting-skill
description: Use when skillify's gate 10 integration test needs a fixture skill that violates the test-home-pollution invariant.
---

# polluting-skill

## Overview
Test fixture for skillify's `check_test_home_pollution.sh` integration. Trigger class: (b) recurring-failure-prevention.

## When to Use
- Inside skillify's gate-10 integration test only.

## When NOT to Use
- Anywhere else.

## Mandatory Procedure
- Be a fixture whose `tests/unit/sample.sh` deliberately writes to the real `$HOME/.claude/skills/` so the gate can demonstrate the rejection path.
