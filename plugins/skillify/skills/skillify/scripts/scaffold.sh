#!/usr/bin/env bash
# Scaffold a new skill directory with the layout that validate.sh expects.
# Usage: scaffold.sh <skill-dir>
# Exit codes: 0 = created, 2 = bad invocation, 3 = directory already exists with content
set -euo pipefail

d="${1:?usage: scaffold.sh <skill-dir>}"
if [[ -e "$d" && -n "$(ls -A "$d" 2>/dev/null || true)" ]]; then
  echo "refusing to scaffold into non-empty path: $d" >&2
  exit 3
fi

mkdir -p "$d"/{scripts,tests/unit,tests/integration,tests/e2e,tests/fixtures,evals}

base="$(basename "$d")"

cat > "$d/SKILL.md" <<MD
---
name: ${base}
description: Use when REPLACE-ME — describe triggering conditions only, do not summarize the workflow.
---

# ${base}

## Overview
TODO — state core principle in 1-2 sentences. Pick a trigger class: (a) verified-success-promotion / (b) recurring-failure-prevention / (c) repeat-task-automation.

## When to Use
TODO

## When NOT to Use
TODO

## Mandatory Procedure
TODO — list deterministic and latent steps.

## Relationship to other skills
TODO — list any sub-skills referenced.
MD

cat > "$d/evals/llm.md"      <<MD
# LLM eval

The strengthened validator requires >=3 scenarios and rejects any leftover
TODO. Replace each TODO with concrete content before shipping.

## Scenario 1 — TODO name this scenario
- Input: TODO describe the user input verbatim.
- Expected: TODO state the expected on-disk side effects.
- Failure mode if procedure skipped: TODO name what bad outcome the gate prevents.

## Scenario 2 — TODO name this scenario
- Input: TODO
- Expected: TODO
- Failure mode if procedure skipped: TODO

## Scenario 3 — TODO name this scenario
- Input: TODO
- Expected: TODO
- Failure mode if procedure skipped: TODO
MD

cat > "$d/evals/resolver.md" <<MD
# Resolver eval

The strengthened validator requires Positive and Negative sections, each with
>=3 enumerated cases, and rejects any leftover TODO.

## Positive triggers (must activate this skill)
1. TODO — concrete user prompt that MUST route to this skill.
2. TODO
3. TODO

## Negative triggers (must NOT activate)
1. TODO — concrete user prompt that MUST NOT route to this skill.
2. TODO
3. TODO
MD

echo "scaffolded $d"
