#!/usr/bin/env bash
# E2E smoke: drives a single canonical skillify pipeline run end-to-end.
#
# Pipeline simulated here (deterministic portion only — the LLM-judgment steps
# are covered by evals/llm.md and evals/resolver.md):
#   step 3  audit_duplicates.sh on the proposed name → must be clean
#   step 6  scaffold.sh produces a compliant skeleton
#   step 7-9 fill minimum required content (script + unit + integration + evals)
#   step 11 validate.sh exits 0
#   step 12 run_tests.sh exits 0
#
# A failure at any stage means the skillify pipeline itself is broken.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
audit="$skill_root/scripts/audit_duplicates.sh"
scaffold="$skill_root/scripts/scaffold.sh"
validate="$skill_root/scripts/validate.sh"
run_tests="$skill_root/scripts/run_tests.sh"

proposed="skillify-e2e-smoke-$$"
# Stage the synthetic skill under a mktemp .claude/skills tree so the location
# gate is satisfied without polluting $HOME/.claude/skills.
tmp_root="$(mktemp -d)"
mkdir -p "$tmp_root/.claude/skills"
target="$tmp_root/.claude/skills/$proposed"
trap 'rm -rf "$tmp_root"' EXIT

# Step 3: DRY audit.
"$audit" "$proposed" "smoke" >/dev/null

# Step 6: scaffold.
"$scaffold" "$target" >/dev/null

# Steps 7–9: fill minimal compliant content.
cat > "$target/SKILL.md" <<MD
---
name: $proposed
description: Use when skillify's E2E smoke test runs — verifies the full pipeline produces a validatable skill.
---

# $proposed

## Overview
Synthetic skill produced by skillify's E2E smoke test. Trigger class: (a) verified-success-promotion.

## When to Use
- Only inside skillify's E2E smoke run.

## When NOT to Use
- Outside the test runner.

## Mandatory Procedure
- Survive validate.sh and run_tests.sh.
MD

cat > "$target/scripts/check.sh" <<'BS'
#!/usr/bin/env bash
exit 0
BS
chmod +x "$target/scripts/check.sh"

cat > "$target/tests/unit/check_test.sh" <<'BS'
#!/usr/bin/env bash
exit 0
BS
chmod +x "$target/tests/unit/check_test.sh"

cat > "$target/tests/integration/check_test.sh" <<'BS'
#!/usr/bin/env bash
exit 0
BS
chmod +x "$target/tests/integration/check_test.sh"

# Replace the scaffold's TODO eval placeholders with compliant content so the
# strengthened validator (>=3 scenarios in llm.md, Positive + Negative
# sections each with >=3 enumerated cases in resolver.md, no leftover TODO)
# accepts the freshly-scaffolded skill.
cat > "$target/evals/llm.md" <<'MD'
# LLM eval

## Scenario 1 — happy path
- Input: smoke-generated skill is filled and validated.
- Expected: validator exits 0.
- Failure mode if procedure skipped: e2e silently passes despite unfilled evals.

## Scenario 2 — boundary: minimal compliant body
- Input: only the required sections present.
- Expected: validator exits 0.
- Failure mode if procedure skipped: validator demands sections beyond the spec.

## Scenario 3 — boundary: maximum description length
- Input: 1024-character description.
- Expected: validator exits 0.
- Failure mode if procedure skipped: off-by-one rejection.
MD

cat > "$target/evals/resolver.md" <<'MD'
# Resolver eval

## Positive triggers (must activate this skill)
1. skillify's e2e smoke run staging this synthetic skill.
2. Explicit reference to the smoke proposed-name.
3. Programmatic copy into the smoke staging location.

## Negative triggers (must NOT activate)
1. Unrelated user prompts.
2. References to other skills.
3. Casual mentions outside the smoke context.
MD

# Step 11: validate.
if ! "$validate" "$target" >/dev/null; then
  echo "E2E: validate.sh failed on the freshly-scaffolded skill" >&2
  exit 1
fi

# Step 12: run all skill-local tests.
if ! "$run_tests" "$target" >/dev/null; then
  echo "E2E: run_tests.sh failed on the freshly-scaffolded skill" >&2
  exit 1
fi

echo "smoke ok: pipeline produced a validatable skill at $target"
