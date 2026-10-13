---
name: no-recommended-skill
description: Use when verifying skillify's validator accepts a SKILL.md authored entirely from the (D1) inline fallback, with zero references to recommended sub-skills.
---

# no-recommended-skill

## Overview
A minimal compliant fixture authored without any reference to `superpowers:*` or `claude-plugins-official:*`. Trigger class: (a) verified-success-promotion.

## When to Use
- Inside skillify's integration test that proves the inline fallback path produces a validatable skill.

## When NOT to Use
- Outside skillify's test suite.

## Mandatory Procedure
- Pass `scripts/validate.sh`.
- Emit no `WARN:` line to stderr because no recommended sub-skill is referenced.

## Relationship to other skills
- Test-only fixture. Authored from skillify's own (D1) SKILL.md authoring fallback.
