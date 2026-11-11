---
name: orchestration-policy
description: Use when the user asks for the orchestration policy by name or asks to apply it ("오케스트레이션 정책 적용해", "apply the orchestration policy"). It is an opt-in policy that routes each step of a coding task to the main session, a subagent (deep-reasoner, feature-developer, fast-worker, log-reader, Explore, flow-tracer), a fork of the session, or an advisor model. Use only when the user asks for it. Do not load it on your own.
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
   If the route names a subagent or `fork`, this skill explicitly asks you to delegate that step.
4. LATENT, then DETERMINISTIC — inside any step, before a search, pick the one fact in "Search facts"
   that holds and run `python3 scripts/route.py search FACT`.
5. LATENT, then DETERMINISTIC — at each event in "Advisor events", run
   `python3 scripts/route.py advisor EVENT --consults N`, where N is the number of advisor consults
   already made in this task. Exit 1 means the budget is spent: ask the user and wait for the answer
   before you consult again.
6. LATENT — if a route names a role that you cannot start (no installed agent with that name,
   or no way to fork your session), do that step yourself.
   Never replace `fork` with a subagent that starts without your conversation. If you cannot fork,
   do the step yourself.
   If no advisor is available, ask the user and wait for the answer where the route says `advisor`.

### Roles

| Role | Use it for |
|------|------------|
| `main` (you) | Edits you can state exactly, and product behavior with its tests |
| `deep-reasoner` | Analysis and designs, when how to solve a problem is still undecided |
| `fork` | A subagent that starts from a copy of your whole conversation and runs on your model. Start it with your agent tool's fork mode. In Claude Code, call the Agent tool with `subagent_type: "fork"`. In Codex, read the arguments that your `spawn_agent` tool lists. If it lists `fork_turns`, set `fork_turns: "all"`. If it lists `fork_context`, set `fork_context: true`. In both cases, omit `agent_type`. Use it for a step that needs your context but whose intermediate output you do not need. Do not use it for a review: it inherits your assumptions |
| `log-reader` | A subagent on a small, cheap model. It runs the command you give it or reads the file you name, and returns only the facts you ask for, such as each failing test with its first error line. It does not edit files |
| `feature-developer` | Product-behavior work with a settled design that splits by context. Writes the tests for its logic |
| `fast-worker` | Fully specified work that only needs to be typed out |
| `Explore` | Broad read-only searches: locating where something lives, or sweeping many files and naming conventions when only the conclusion is needed. Returns `path:line` findings |
| `flow-tracer` | Read-only searches that trace a flow or need judgment |
| `critic` | Any general agent in a fresh context. Give it only the problem and the recommended option, and have it argue against the option. |
| `advisor` | A stronger reviewer model that sees the whole conversation. Judgment only. In Claude Code, call the advisor tool. In Codex, an advisor is available only if your `spawn_agent` tool lists both an `advisor` agent type and `fork_turns`. Then call `spawn_agent` with `agent_type: "advisor"` and `fork_turns: "all"`. A `spawn_agent` tool that lists `fork_context` rejects a fork that sets `agent_type`, so it has no advisor |
| `user` | Ask the user and wait for the answer |

In Codex, if your `spawn_agent` tool lists `fork_turns`, set `fork_turns: "none"` for every role except
`fork` and `advisor`. That tool copies your whole conversation into the subagent by default.
A role that starts without your conversation needs a brief that carries the whole step.

### Step facts
Rules are in order. The first rule whose fact holds wins.

| Rule | Facts | Holds when | Route |
|------|-------|------------|-------|
| 1 | `exact-edit` | You have already read every file the change touches, and you can state the exact edit (file + what changes) in one or two sentences | `main` |
| 2 | `costly-decision` | The step locks in a costly-to-revert decision (architecture, DB schema, API contracts, migrations, technology choices), and the options are settled | `advisor` |
| 2 | `costly-decision options-open` | As above, but the options are still open | `deep-reasoner`, then `critic` if it returns two or more options with no clear winner, then `advisor` |
| 3 | `undecided` | How to solve it is still undecided: root cause unknown after one investigation pass, or two or more viable designs or algorithms | `deep-reasoner` |
| 4 | `context-bound-bulk` | All three hold. (a) The step needs your conversation context (the user's intent, earlier decisions, constraints), and a brief cannot carry it. (b) The step makes large intermediate output (tens of files to read, a long test log), and you need only its conclusion. (c) The session goes on long after this step, or your context is close to compaction | `fork` |
| 5 | `bulk-output` | All three hold. (a) The step makes large output (a long test, build, or tool log), and you need only facts from it. (b) A brief carries the whole step: the command or file, and the facts to return. (c) You can check the facts it returns, for example by test name or exit code | `log-reader` |
| 6 | `product-behavior` | The change decides what the product does: new or changed behavior, domain rules, edge-case handling | `main` |
| 6 | `product-behavior splits-by-context` | As above, and the work splits by context: a large part that needs little of your context and returns a compact result, or independent parts that run in parallel | `feature-developer` |
| 7 | `fully-specified` | The outcome is fully specified and only needs to be typed out: boilerplate, renames, formatting, the same edit across many files, tests whose cases are already listed | `fast-worker` |
| default | none | No rule above matches: answering a question, running a short test, committing, reporting | `main` |

### Search facts

| Facts | Holds when | Route |
|-------|------------|-------|
| `few-calls` | One or two grep or glob calls will find it | `main` |
| `locate` | Locating where something lives (file, symbol, config key, keyword) across many places | `Explore` |
| `trace` | Tracing a flow, or a search that needs judgment | `flow-tracer` |
| `why` | Understanding why something happens | `deep-reasoner` |

### Advisor events
The advisor is for judgment only. Never delegate code writing, exploration, or testing to it.

| Facts | Holds when | Route |
|-------|------------|-------|
| `costly-decision` | Before you lock in a costly-to-revert decision | `advisor` |
| `large-plan` | Before you finalize a large plan, including before you exit plan mode | `advisor` |
| `repeat-error` | The same error reappears after two genuinely different fix attempts. Before you consult, make sure a test or script reproduces the error | `advisor` |
| `declare-done` | Before you declare a long task, or hard-to-revert work such as a deploy or migration, done | `advisor` |
| `trivial` | Trivial edits, straightforward implementation of a settled design, or questions a docs lookup can answer | none |
| `rephrase` | Re-asking the same question in different words | none |

At most 3 consults per task. The script returns `user` for a 4th consult.

Follow the advice by default. If it conflicts with file contents or test results, do not follow it.
Report the conflict to the user instead.
Subagents do not consult the advisor directly. If they need a judgment call, they put the open
question in their final report for the main session to decide.

## Relationship to other skills
- The subagents it names (`deep-reasoner`, `feature-developer`, `fast-worker`, `log-reader`,
  `flow-tracer`) are not part of this plugin. Map each role in "Roles" to an agent of your own.
  Give `log-reader` and `Explore` a small model: they exist so that bulk reading costs less than in
  your session. `Explore` is Claude Code's built-in search agent. It runs on your session's model,
  so a user or project agent named `Explore` that sets a small model is what makes the `locate`
  route cheap.
- `fork` is not an installed agent. It is a mode of your agent tool. The "Roles" table says how to
  start it in Claude Code and in Codex.
- Codex has no built-in `advisor` agent type. The user defines it as an agent role with a stronger
  model. The "Roles" table says when Codex can start it.
- The skillify duplicate audit found no other skill that routes work between the main session,
  subagents, and an advisor. Its keyword hits (`subagent`, `advisor`, `routing`, `delegate`) are
  generic words in skills for other jobs.
