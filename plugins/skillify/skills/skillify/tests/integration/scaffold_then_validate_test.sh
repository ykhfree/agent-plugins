#!/usr/bin/env bash
# Integration test: scaffold a fresh skill, fill in the minimum required content,
# and confirm validate.sh passes — proves the bootstrap path works end-to-end.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
scaffold="$skill_root/scripts/scaffold.sh"
validate="$skill_root/scripts/validate.sh"

# Stage the scaffold under a mktemp .claude/skills tree to satisfy the
# location gate without touching $HOME/.claude/skills.
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT
mkdir -p "$tmp_root/.claude/skills"
target="$tmp_root/.claude/skills/skillify-scaffold-test-$$"

"$scaffold" "$target" >/dev/null

# Fill in the SKILL.md with a compliant body (no hedging words, real overview).
cat > "$target/SKILL.md" <<MD
---
name: $(basename "$target")
description: Use when running skillify's scaffold integration test — replaces the placeholder body the scaffold inserts.
---

# $(basename "$target")

## Overview
A throwaway skill produced by skillify's integration test. Trigger class: (a) verified-success-promotion.

## When to Use
- Only inside skillify's integration test.

## When NOT to Use
- Anywhere else.

## Mandatory Procedure
- Pass validate.sh.
MD

# Add a tiny executable so scripts/ is non-empty and executable.
echo '#!/usr/bin/env bash' > "$target/scripts/noop.sh"
echo 'exit 0'              >> "$target/scripts/noop.sh"
chmod +x "$target/scripts/noop.sh"

# Tests directories must be non-empty too.
echo '#!/usr/bin/env bash' > "$target/tests/unit/noop_test.sh"
echo 'exit 0'              >> "$target/tests/unit/noop_test.sh"
chmod +x "$target/tests/unit/noop_test.sh"

cp "$target/tests/unit/noop_test.sh" "$target/tests/integration/noop_test.sh"

# Replace scaffold's TODO eval placeholders with compliant content. The
# strengthened validator rejects any evals file that still contains the
# literal "TODO", and demands >=3 scenarios in llm.md plus Positive +
# Negative sections (each with >=3 enumerated cases) in resolver.md.
cat > "$target/evals/llm.md" <<'MD'
# LLM eval

## Scenario 1 — happy path
- Input: scaffolded skill is filled out and shipped.
- Expected: validator exits 0.
- Failure mode if procedure skipped: empty placeholders slip past the gate.

## Scenario 2 — boundary: minimal compliant body
- Input: only the required sections are present.
- Expected: validator exits 0.
- Failure mode if procedure skipped: validator demands content beyond the spec.

## Scenario 3 — boundary: maximum description length
- Input: 1024-character description.
- Expected: validator exits 0.
- Failure mode if procedure skipped: off-by-one rejection.
MD

cat > "$target/evals/resolver.md" <<'MD'
# Resolver eval

## Positive triggers (must activate this skill)
1. skillify's scaffold-then-validate integration test injecting this fixture.
2. Explicit reference to the test name.
3. Programmatic copy into a candidate location.

## Negative triggers (must NOT activate)
1. Unrelated user prompts.
2. References to other skills.
3. Casual mentions outside the test context.
MD

if ! "$validate" "$target" >/dev/null; then
  echo "scaffolded skill failed validation" >&2
  exit 1
fi

echo "scaffold_then_validate_test ok"
