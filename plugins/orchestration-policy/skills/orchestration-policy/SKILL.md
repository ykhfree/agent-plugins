---
name: orchestration-policy
description: An opt-in policy that routes each step of a coding task to the main session, a subagent (deep-reasoner, feature-developer, fast-worker, fast-explorer, Explore), or an advisor model, by five ordered rules plus search and advisor rules. Use only when the user asks for it by name or asks to apply the orchestration policy ("오케스트레이션 정책 적용해", "apply the orchestration policy"). Do not load it on your own.
---

# orchestration-policy

This policy decides who does each step of a task: you (the main session), a subagent, or the advisor.
After the user invokes it, apply it to every task in the session until the user says to stop.

## Roles

| Role | Use it for |
|------|------------|
| You (main session) | Edits you can state exactly, and product behavior with its tests |
| deep-reasoner | Analysis and designs, when how to solve a problem is still undecided |
| feature-developer | Product-behavior work with a settled design that splits by context. Writes the tests for its logic |
| fast-worker | Fully specified work that only needs to be typed out |
| fast-explorer | Pure location lookups. Returns paths and line numbers |
| Explore | Read-only searches that trace a flow or need judgment |
| Critic | Any general agent in a fresh context, told to argue against one option |
| Advisor | A stronger reviewer model that sees the whole conversation (Claude Code's advisor tool). Judgment only |

If no agent with a role is installed, do that step yourself.
If no advisor is available, ask the user and wait for the answer at each point where a rule says to consult the advisor.

## Routing rules

Evaluate top to bottom; the first rule that matches wins. Final calls are always yours — subagents advise.
1. You have already read every file the change touches, and you can state the exact edit
   (file + what changes) in one or two sentences → do it yourself. Spawning an agent costs more.
2. The task locks in a costly-to-revert decision (the first item under "Always consult" below)
   → if the options are still open, design with deep-reasoner. If it returns two or more
   options with no clear winner, spawn one critic agent in a fresh context — give it only
   the problem and the recommended option, and have it argue against it. Then consult
   the advisor with both before committing.
3. How to solve it is still undecided — root cause unknown after one investigation pass, or two or
   more viable designs/algorithms to choose between → deep-reasoner.
4. The change decides what the product does — new or changed behavior, domain rules,
   edge-case handling → implement it yourself, with its tests. This keeps the context you built in one loop.
   Delegate to feature-developer only if the work splits by context: a large part that needs
   little of your context and returns a compact result, or independent parts that run in parallel.
5. The outcome is fully specified and only needs to be typed out — boilerplate, renames, formatting,
   the same edit across many files, tests whose cases are already listed → fast-worker.

A task that spans several rules is split into steps, each routed on its own
(e.g. deep-reasoner picks the design → you implement it).

## Search steps

Inside any task:
- One or two grep/glob calls will find it → search yourself.
- Locating where something lives (file, symbol, config key, keyword) across many places → fast-explorer.
- Tracing a flow or a search that needs judgment → Explore.
- Understanding why something happens → deep-reasoner (rule 3).

## Advisor rules

The advisor is for judgment only. Never delegate code writing, exploration, or testing to it.

Always consult:
- Before locking in a costly-to-revert decision (architecture, DB schema, API contracts, migrations, technology choices)
- Before finalizing a large plan (including before exiting plan mode)
- When the same error reappears after two genuinely different fix attempts
- Before declaring a long task, or any hard-to-revert work such as a deploy or migration, "done"

Never consult for:
- Trivial edits, straightforward implementation of an already-settled design, or questions a docs lookup can answer
- Re-asking the same question in different words

Operating rules:
- Max 3 consults per task. If more seem necessary, ask the user first.
- Follow the advice by default, but if it conflicts with file contents or test results, don't follow it; report the conflict to the user instead.
- Subagents do not consult the advisor directly. If they need a judgment call, they put the open question in their final report for the main session to decide.
