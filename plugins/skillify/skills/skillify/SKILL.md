---
name: skillify
description: Use when a validated solution, recurring failure, or recurrence-risk pattern must be converted from a one-off conversation outcome into a permanent reusable skill — triggered by phrases like "skillify", "이걸 스킬로 만들어", "다음에도 기억해", "영구화", "재발 방지", "표준화", "템플릿화", "다음부터 이렇게 처리해", or when the same class of failure has occurred more than once.
---

# skillify

## Overview

Promotes ad-hoc solutions and lessons learned into permanent, deterministic, testable skills. The output is never a prompt fix or a chat summary — it is a directory on disk containing a SKILL.md, executable code, tests, evals, and a registered trigger, such that the next occurrence of the same problem is handled structurally instead of re-derived.

Done means the same failure cannot happen the same way again — not that the fix worked once.

## When to Use

Trigger this skill when ANY of the following holds:

- The user types `skillify`, `이걸 스킬로 만들어`, `영구화`, `재발 방지`, `표준화`, `템플릿화`, `다음부터 이렇게 처리해`, or any synonym
- The same class of failure has occurred more than once, in the current or a prior session
- The agent solved a problem by reasoning that a deterministic script could have solved
- A pattern was validated in real use and has cross-project reuse value
- The user implies they want future automation of the same workflow

## When NOT to Use

- One-off cosmetic fix with no recurrence risk
- Project-specific convention → put in `AGENTS.md` for Codex or `CLAUDE.md` for Claude Code instead
- Mechanical constraint already enforced by lint/regex/CI → that IS the deterministic solution; do not wrap it in a skill
- Solution still unverified in production → run it once first, then skillify

## Mandatory Procedure

Complete the steps in order. The skill is done when the step 11 gate exits 0, step 12 passes, and step 13 shows the original failure blocked.

### Step 1 — Classify the trigger
Pick exactly one: `(a) verified-success-promotion`, `(b) recurring-failure-prevention`, `(c) repeat-task-automation`. Write the choice into the resulting SKILL.md `Overview`.

### Step 2 — Split latent vs deterministic
For the problem being skillified, list every sub-step. Mark each `LATENT` (requires model judgment) or `DETERMINISTIC` (resolvable with code, regex, or a fixed lookup). If you mark a step `LATENT` because writing the code is hard, that is wrong — mark it `DETERMINISTIC` and write the code.

### Step 3 — Search for duplication (DRY audit) — DETERMINISTIC
Resolve `skillify_dir` to the directory containing this SKILL.md, then run:
```bash
"$skillify_dir/scripts/audit_duplicates.sh" "<proposed-skill-name>" "<keyword>" ["<keyword>" ...]
```
If the script reports collisions or ≥3 keyword overlap hits, (a) extend the existing skill, (b) merge under a more general parent, or (c) document why the new skill is genuinely orthogonal in `SKILL.md` § "Relationship to other skills". A parallel skill splits triggers and fixes between two places.

### Step 4 — Decide global vs project scope
- Cross-project applicability → `~/.agents/skills/<name>/` or `~/.codex/skills/<name>/` for Codex; `~/.claude/skills/<name>/` for Claude Code
- Single-repo policy → `<repo>/.agents/skills/<name>/` or `<repo>/.codex/skills/<name>/` for Codex; `<repo>/.claude/skills/<name>/` for Claude Code
- Personal automation → global

### Step 5 — Author SKILL.md
Use `$skill-creator` in Codex. In Claude Code, use `superpowers:writing-skills` or `claude-plugins-official:skill-creator` when installed. When the runtime has none of these helpers, follow the **(D1) SKILL.md authoring fallback** in `## Inline fallback procedures` below. Forbidden words in the body: `가능하면`, `보통`, `웬만하면`, `possibly`, `usually`, `try to`. Replace them with absolute rules or explicit "When NOT to use" exceptions.

### Step 6 — Write deterministic code
For every step you marked `DETERMINISTIC` in step 2, ship an executable file under `scripts/` of the new skill directory. Each script MUST have:
- A documented input contract (stdin / args / env)
- A documented output contract (stdout / exit code)
- Exit code `0` on success, non-zero on policy violation

Bootstrap with `scripts/scaffold.sh <new-skill-dir>` to get the directory layout right the first time.

### Step 7 — Write unit tests
In Claude Code, use `superpowers:test-driven-development` when installed. In every runtime, follow the **(D2) Minimum test discipline fallback** below. For each script in `scripts/`, write a unit test under `tests/unit/`. Cover: happy path, two boundary inputs, and two failure inputs.

### Step 8 — Write integration tests
At least one test under `tests/integration/` MUST exercise the script against a real example skill directory (use `tests/fixtures/`). External dependencies stubbed only when they cannot be reached locally.

### Step 9 — Write LLM eval + resolver eval
- `evals/llm.md` — three scenarios; for each, the expected behavior and the failure mode if the model skips the procedure.
- `evals/resolver.md` — three positive trigger cases (must route to the new skill) and three negative cases (must NOT route, e.g., trivial typo fix).

### Step 10 — Register the resolver trigger
Add the trigger phrases to the `description:` frontmatter of the new skill. If the trigger needs to fire on hook events (e.g., "after second occurrence of same error"), add a corresponding `UserPromptSubmit` or `PostToolUse` hook to `.codex/hooks.json` for Codex or `settings.json` for Claude Code. Validate the changed JSON with `jq empty <path>` so malformed JSON cannot break hook loading.

### Step 11 — Run the deterministic gate
```bash
"$skillify_dir/scripts/validate.sh" <skill-dir>
```
Exit code MUST be 0. The gate verifies:
1. SKILL.md exists and frontmatter parses
2. `name` matches `^[a-z0-9-]+$` and equals the directory name
3. `description` starts with "Use when" and is ≤ 1024 chars
4. No forbidden hedging words in body
5. `scripts/` non-empty AND every script is executable
6. `tests/unit/` non-empty
7. `tests/integration/` non-empty
8. `evals/llm.md` and `evals/resolver.md` exist, are non-empty, contain no leftover `TODO` placeholders, and satisfy Step 9's structural requirements — `llm.md` has ≥3 scenarios (markdown headers containing "Scenario"/"Case", or top-level enumerated list items); `resolver.md` has a "Positive" section with ≥3 enumerated cases and a "Negative" section with ≥3 enumerated cases
9. The skill is reachable. Accepted location patterns (matched against the resolved absolute path): user or project skills under `.claude/skills`, `.agents/skills`, or `.codex/skills`, plus Claude Code or Codex plugin cache skill paths. Other locations fail the gate.
10. No test under `tests/{unit,integration,e2e}/*.sh` writes to the real `$HOME/.claude/skills/`, `$HOME/.agents/skills/`, or `$HOME/.codex/skills/` outside a comment. Tests MUST stage into `mktemp -d` and use `HOME=` env injection when a real skill-path pattern itself needs exercising. Paths under `*/fixtures/*` are skipped so a deliberate polluting fixture can ship without tripping its parent skill's gate.

### Step 12 — Run the full test suite
```bash
"$skillify_dir/scripts/run_tests.sh" <skill-dir>
```
The runner executes EVERY test twice: once with the inherited environment, then once with `HOME` redirected to a fresh `mktemp -d`. Both passes MUST exit 0; a test that depends on the operator's real `$HOME` is rejected by the isolated pass even when gate 10's static scan accepts it. The `SKILLIFY_RUN_TESTS_SKIP_ISOLATED=1` env var disables the isolated pass — use it only as a CI-time escape hatch when tests legitimately cannot run under sandboxed HOME.

### Step 13 — Verify recurrence prevention
In Claude Code, use `superpowers:verification-before-completion` when installed. In every runtime, follow the **(D3) Recurrence verification checklist** below. Reproduce the original failing scenario. The new skill MUST cause it to be handled deterministically without the same reasoning step that failed before. If you cannot reproduce, you cannot claim done.

## Done criteria

- Steps 1–13 are all complete. Without scripts, tests, and evals the result is a design note, not a skill.
- Checks that the step 11 gate automates are left to the gate, not repeated by hand.

## Relationship to other skills

- **`$skill-creator`** — Codex helper for step 5. It does not replace steps 6–13. Inline fallback: (D1) below.
- **`superpowers:writing-skills`** — Claude Code helper for step 5. Skillify wraps it with a broader pipeline. Inline fallback: (D1) below.
- **`superpowers:test-driven-development`** — Recommended foundation discipline for steps 7–9. Inline fallback: (D2) below.
- **`superpowers:verification-before-completion`** — Recommended for step 13. Inline fallback: (D3) below.
- **`claude-plugins-official:skill-creator`** — Claude Code authoring helper for step 5. It does not replace steps 6–13. Inline fallback: (D1) below.

Run `scripts/check_recommended_skills.sh` to see which of the five are installed in the current runtime.

## Inline fallback procedures

These procedures stand in for the recommended sub-skills when those skills are not installed in the runtime. Use them in addition to, not instead of, the recommended skills when both are available.

### (D1) SKILL.md authoring fallback — use when no runtime authoring helper is installed

Required frontmatter:

```yaml
---
name: <kebab-case>
description: Use when <triggering condition stated in concrete terms>
---
```

Rules enforced by `scripts/validate.sh`:

- `name` matches `^[a-z0-9-]+$` and equals the directory name.
- `description` starts with the literal string `Use when` and is ≤ 1024 characters.
- `description` states triggering conditions only — never a workflow summary.

Required body sections in this order: `## Overview`, `## When to Use`, `## When NOT to Use`, `## Mandatory Procedure`, `## Relationship to other skills`.

Forbidden hedging words in the body — replace each with an absolute rule or a named exception in `## When NOT to Use`: `가능하면`, `보통`, `웬만하면`, `possibly`, `usually`, `try to`. The validator strips inline code spans, fenced code blocks, and the `## Rationalization table` section before checking, so these words may appear inside backticks as examples.

### (D2) Minimum test discipline fallback

For each script in `scripts/`, the corresponding test file under `tests/unit/` MUST cover at least 5 cases: 1 happy path, 2 boundary inputs, 2 failure inputs.

At least one test under `tests/integration/` MUST run a script against a real skill directory placed in `tests/fixtures/`. External dependencies stubbed only when they cannot be reached locally.

`evals/llm.md` MUST contain 3 scenarios; each scenario states the user input, the expected behavior, and the failure mode if the procedure is skipped.

`evals/resolver.md` MUST contain 3 positive routing cases (must activate the skill) and 3 negative routing cases (must NOT activate).

### (D3) Recurrence verification checklist

Complete every step in order. The skill is not done until step 4 is recorded.

1. Write down the original failing input verbatim — the exact prompt, file state, command, or stack trace that produced the failure.
2. Replay that input against the new skill's deterministic scripts.
3. Confirm the script exits non-zero (or otherwise blocks the bad pattern). A passing exit code on a known-bad input means the skill does not prevent recurrence — restart at step 6 of the mandatory procedure.
4. Quote the resulting stdout and exit code in the commit message or PR body that ships the skill, so reviewers can audit the recurrence-prevention claim.

## Quick reference

| Need | Run |
|---|---|
| Audit duplicates before naming | `scripts/audit_duplicates.sh <name> <keyword> [<keyword> …]` |
| Scaffold a new skill directory | `scripts/scaffold.sh <skill-dir>` |
| Validate the skill directory | `scripts/validate.sh <skill-dir>` |
| Run all skill-local tests | `scripts/run_tests.sh <skill-dir>` |
| Check which recommended sub-skills are installed | `scripts/check_recommended_skills.sh` |
