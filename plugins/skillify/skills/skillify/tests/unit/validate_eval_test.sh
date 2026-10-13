#!/usr/bin/env bash
# Unit test: validate.sh eval structural gate.
#
# Exercises the strengthened evals check: rejects leftover TODO placeholders,
# requires >=3 scenarios in evals/llm.md, and requires Positive + Negative
# sections (each with >=3 enumerated cases) in evals/resolver.md.
set -euo pipefail

skill_root="$(cd "$(dirname "$0")/../.." && pwd)"
validate="$skill_root/scripts/validate.sh"
fixture="$skill_root/tests/fixtures/valid-skill"

# Stage the work tree under a mktemp .claude/skills/eval-test prefix so each
# variant path satisfies the location gate (`*/.claude/skills/*`) without
# polluting $HOME/.claude/skills.
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT
work="$tmp_root/.claude/skills/eval-test"
mkdir -p "$work"

# Seed each test with the compliant valid-skill fixture and then mutate only
# the eval files. Every variant ends in `/valid-skill` so the name-match gate
# stays satisfied.
make_variant() {
  local name="$1"
  local target="$work/$name/valid-skill"
  rm -rf "$target"
  mkdir -p "$work/$name"
  cp -R "$fixture" "$target"
  echo "$target"
}

# Sanity: pristine fixture passes.
sanity="$(make_variant sanity)"
"$validate" "$sanity" >/dev/null \
  || { echo "sanity: pristine fixture must pass" >&2; exit 1; }

# (a) Leftover TODO in evals/llm.md must fail.
todo_llm="$(make_variant todo_llm)"
printf '\nTODO — finish me\n' >> "$todo_llm/evals/llm.md"
if "$validate" "$todo_llm" >/dev/null 2>&1; then
  echo "(a) expected TODO in evals/llm.md to fail validation" >&2; exit 1
fi

# (b) Leftover TODO in evals/resolver.md must fail.
todo_res="$(make_variant todo_res)"
printf '\nTODO — finish me\n' >> "$todo_res/evals/resolver.md"
if "$validate" "$todo_res" >/dev/null 2>&1; then
  echo "(b) expected TODO in evals/resolver.md to fail validation" >&2; exit 1
fi

# (c) Fewer than 3 scenarios in evals/llm.md must fail.
two_sc="$(make_variant two_sc)"
cat > "$two_sc/evals/llm.md" <<'MD'
# LLM eval

## Scenario 1 — only one
- Input: x
- Expected: y
- Failure mode if procedure skipped: z

## Scenario 2 — only two
- Input: x
- Expected: y
- Failure mode if procedure skipped: z
MD
if "$validate" "$two_sc" >/dev/null 2>&1; then
  echo "(c) expected <3 scenarios to fail validation" >&2; exit 1
fi

# (d) Missing Positive section must fail.
no_pos="$(make_variant no_pos)"
cat > "$no_pos/evals/resolver.md" <<'MD'
# Resolver eval

## Negative triggers (must NOT activate)
1. unrelated
2. unrelated
3. unrelated
MD
if "$validate" "$no_pos" >/dev/null 2>&1; then
  echo "(d) expected missing Positive section to fail validation" >&2; exit 1
fi

# (e) Missing Negative section must fail.
no_neg="$(make_variant no_neg)"
cat > "$no_neg/evals/resolver.md" <<'MD'
# Resolver eval

## Positive triggers (must activate this skill)
1. on-topic
2. on-topic
3. on-topic
MD
if "$validate" "$no_neg" >/dev/null 2>&1; then
  echo "(e) expected missing Negative section to fail validation" >&2; exit 1
fi

# (f) Positive section with only 2 enumerated items must fail.
short_pos="$(make_variant short_pos)"
cat > "$short_pos/evals/resolver.md" <<'MD'
# Resolver eval

## Positive triggers (must activate this skill)
1. one
2. two

## Negative triggers (must NOT activate)
1. unrelated
2. unrelated
3. unrelated
MD
if "$validate" "$short_pos" >/dev/null 2>&1; then
  echo "(f) expected <3 enumerated cases under Positive to fail validation" >&2; exit 1
fi

# (g) Newly scaffolded skill (TODO placeholders) must fail.
scaffold="$skill_root/scripts/scaffold.sh"
fresh="$work/freshly_scaffolded/valid-skill"
"$scaffold" "$fresh" >/dev/null
# Make the SKILL.md frontmatter compliant so we are testing the eval gate
# specifically, not the frontmatter gate.
cat > "$fresh/SKILL.md" <<'MD'
---
name: valid-skill
description: Use when checking that a freshly scaffolded skill fails the eval gate before TODOs are filled in.
---

# valid-skill

## Overview
Test fixture asserting unfilled scaffolds fail the validator.

## When to Use
- Inside skillify's eval-gate unit test only.

## When NOT to Use
- Anywhere else.

## Mandatory Procedure
- Be a freshly scaffolded skill with TODO placeholders intact.
MD
echo '#!/usr/bin/env bash' > "$fresh/scripts/noop.sh"
echo 'exit 0'              >> "$fresh/scripts/noop.sh"
chmod +x "$fresh/scripts/noop.sh"
echo '#!/usr/bin/env bash' > "$fresh/tests/unit/noop_test.sh"
echo 'exit 0'              >> "$fresh/tests/unit/noop_test.sh"
chmod +x "$fresh/tests/unit/noop_test.sh"
cp "$fresh/tests/unit/noop_test.sh" "$fresh/tests/integration/noop_test.sh"
if "$validate" "$fresh" >/dev/null 2>&1; then
  echo "(g) expected freshly-scaffolded skill (TODO placeholders) to fail validation" >&2
  exit 1
fi

echo "validate_eval_test ok"
