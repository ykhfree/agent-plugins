---
name: orchestration-policy
description: Use when the user asks for the orchestration policy by name or asks to apply it ("오케스트레이션 정책 적용해", "apply the orchestration policy"). It is an opt-in policy that routes each step of a coding task to the main session, a subagent (deep-reasoner, feature-developer, fast-worker, fast-explorer, Explore), or an advisor model. Use only when the user asks for it. Do not load it on your own.
---

# orchestration-policy

## Overview
Trigger class: (a) verified-success-promotion.

This policy decides who does each step of a task: you (the main session), a subagent, or the advisor.
After the user invokes it, apply it to every task in the session until the user says to stop.

You judge the facts of a step (LATENT). `scripts/route.py` applies the rules to those facts
(DETERMINISTIC): the rule order, the outcomes, and the advisor budget live in the script.
The tables below define each fact and show the outcome the script gives.
The integration test checks that the tables and the script agree.

Final calls are always yours. Subagents advise.

## When to Use
- The user asks for this policy by name, or asks to apply the orchestration policy.
- The user invoked it earlier in this session and has not said to stop.

## When NOT to Use
- The user has not asked for it. Do not load it on your own, even for a task with many steps.
- The user said to stop applying it.

## Mandatory Procedure
The script path is relative to this skill's directory. Python 3.10 or later.

1. LATENT — split the task into steps. Route each step on its own
   (for example, deep-reasoner picks the design, then you implement it).
2. LATENT — for each step, decide which facts in "Step facts" hold.
3. DETERMINISTIC — run `python3 scripts/route.py step FACT...` and follow its `route` and `note`.
   If no fact holds, the script returns the default route, `main`. Exit 2 means bad input.
4. LATENT, then DETERMINISTIC — inside any step, before a search, pick the one fact in "Search facts"
   that holds and run `python3 scripts/route.py search FACT`.
5. LATENT, then DETERMINISTIC — at each event in "Advisor events", run
   `python3 scripts/route.py advisor EVENT --consults N`, where N is the number of advisor consults
   already made in this task. Exit 1 means the budget is spent: ask the user and wait for the answer
   before you consult again.
6. LATENT — if a route names a role that has no installed agent, do that step yourself.
   If no advisor is available, ask the user and wait for the answer where the route says `advisor`.

### Roles

| Role | Use it for |
|------|------------|
| `main` (you) | Edits you can state exactly, and product behavior with its tests |
| `deep-reasoner` | Analysis and designs, when how to solve a problem is still undecided |
| `feature-developer` | Product-behavior work with a settled design that splits by context. Writes the tests for its logic |
| `fast-worker` | Fully specified work that only needs to be typed out |
| `fast-explorer` | Pure location lookups. Returns paths and line numbers |
| `Explore` | Read-only searches that trace a flow or need judgment |
| `critic` | Any general agent in a fresh context. Give it only the problem and the recommended option, and have it argue against the option |
| `advisor` | A stronger reviewer model that sees the whole conversation (Claude Code's advisor tool). Judgment only |
| `user` | Ask the user and wait for the answer |

### Step facts
Rules are in order. The first rule whose fact holds wins.

| Rule | Facts | Holds when | Route |
|------|-------|------------|-------|
| 1 | `exact-edit` | You have already read every file the change touches, and you can state the exact edit (file + what changes) in one or two sentences | `main` |
| 2 | `costly-decision` | The step locks in a costly-to-revert decision (architecture, DB schema, API contracts, migrations, technology choices), and the options are settled | `advisor` |
| 2 | `costly-decision options-open` | As above, but the options are still open | `deep-reasoner`, then `critic` if it returns two or more options with no clear winner, then `advisor` |
| 3 | `undecided` | How to solve it is still undecided: root cause unknown after one investigation pass, or two or more viable designs or algorithms | `deep-reasoner` |
| 4 | `product-behavior` | The change decides what the product does: new or changed behavior, domain rules, edge-case handling | `main` |
| 4 | `product-behavior splits-by-context` | As above, and the work splits by context: a large part that needs little of your context and returns a compact result, or independent parts that run in parallel | `feature-developer` |
| 5 | `fully-specified` | The outcome is fully specified and only needs to be typed out: boilerplate, renames, formatting, the same edit across many files, tests whose cases are already listed | `fast-worker` |
| default | none | No rule above matches: answering a question, running tests, committing, reporting | `main` |

### Search facts

| Facts | Holds when | Route |
|-------|------------|-------|
| `few-calls` | One or two grep or glob calls will find it | `main` |
| `locate` | Locating where something lives (file, symbol, config key, keyword) across many places | `fast-explorer` |
| `trace` | Tracing a flow, or a search that needs judgment | `Explore` |
| `why` | Understanding why something happens | `deep-reasoner` |

### Advisor events
The advisor is for judgment only. Never delegate code writing, exploration, or testing to it.

| Facts | Holds when | Route |
|-------|------------|-------|
| `costly-decision` | Before you lock in a costly-to-revert decision | `advisor` |
| `large-plan` | Before you finalize a large plan, including before you exit plan mode | `advisor` |
| `repeat-error` | The same error reappears after two genuinely different fix attempts | `advisor` |
| `declare-done` | Before you declare a long task, or hard-to-revert work such as a deploy or migration, done | `advisor` |
| `trivial` | Trivial edits, straightforward implementation of a settled design, or questions a docs lookup can answer | none |
| `rephrase` | Re-asking the same question in different words | none |

At most 3 consults per task. The script returns `user` for a 4th consult.

Follow the advice by default. If it conflicts with file contents or test results, do not follow it.
Report the conflict to the user instead.
Subagents do not consult the advisor directly. If they need a judgment call, they put the open
question in their final report for the main session to decide.

## Relationship to other skills
- The subagents it names (`deep-reasoner`, `feature-developer`, `fast-worker`, `fast-explorer`) are
  not part of this plugin. Map each role in "Roles" to an agent of your own.
- The skillify duplicate audit found no other skill that routes work between the main session,
  subagents, and an advisor. Its keyword hits (`subagent`, `advisor`, `routing`, `delegate`) are
  generic words in skills for other jobs.
