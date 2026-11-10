#!/usr/bin/env python3
"""Apply the orchestration-policy rules to facts you have judged about one step.

Input:  argv, one of
          step FACT...                  facts: exact-edit, costly-decision, options-open, undecided,
                                        context-bound-bulk, bulk-output, product-behavior,
                                        splits-by-context, fully-specified
          search FACT                   exactly one of: few-calls, locate, trace, why
          advisor EVENT --consults N    EVENT: costly-decision, large-plan, repeat-error, declare-done,
                                        trivial, rephrase; N = advisor consults already made in this task
        SKILL.md defines when each fact or event holds.
Output: one JSON object on stdout, {"rule", "route", "note"}.
        route: the roles to use, in order (main, deep-reasoner, critic, advisor, fork, log-reader,
        feature-developer, fast-worker, Explore, flow-tracer, user). An empty route means "do not consult".
        A step that matches no rule gets the default route, main.
Exit:   0 follow the route, 1 the advisor budget is spent and you must ask the user,
        2 bad input (message on stderr as "route: <message>").
"""

import json
import sys

ADVISOR_BUDGET = 3

# Step rules in order; the first rule whose fact is given wins.
STEP_FACTS = (
    "exact-edit",
    "costly-decision",
    "undecided",
    "context-bound-bulk",
    "bulk-output",
    "product-behavior",
    "fully-specified",
)
# A modifier changes the outcome of the rule it belongs to.
MODIFIERS = {"options-open": "costly-decision", "splits-by-context": "product-behavior"}

SEARCH = {"few-calls": "main", "locate": "Explore", "trace": "flow-tracer", "why": "deep-reasoner"}
ADVISOR_ALWAYS = ("costly-decision", "large-plan", "repeat-error", "declare-done")
ADVISOR_NEVER = ("trivial", "rephrase")


class BadInput(Exception):
    pass


def step(facts: list[str]) -> tuple[int, dict]:
    given = set(facts)
    unknown = given - set(STEP_FACTS) - set(MODIFIERS)
    if unknown:
        raise BadInput(f"unknown facts {sorted(unknown)}; known: {list(STEP_FACTS) + list(MODIFIERS)}")
    for modifier, parent in MODIFIERS.items():
        if modifier in given and parent not in given:
            raise BadInput(f"{modifier} needs {parent}")

    for number, fact in enumerate(STEP_FACTS, 1):
        if fact not in given:
            continue
        if fact == "exact-edit":
            return 0, {"rule": number, "route": ["main"], "note": "do it yourself; spawning an agent costs more"}
        if fact == "costly-decision":
            if "options-open" in given:
                return 0, {
                    "rule": number,
                    "route": ["deep-reasoner", "critic", "advisor"],
                    "note": "use the critic only if deep-reasoner returns two or more options with no clear winner",
                }
            return 0, {"rule": number, "route": ["advisor"], "note": "consult the advisor before committing"}
        if fact == "undecided":
            return 0, {"rule": number, "route": ["deep-reasoner"], "note": "deep-reasoner designs; final calls are yours"}
        if fact == "context-bound-bulk":
            return 0, {
                "rule": number,
                "route": ["fork"],
                "note": "fork your session, not a fresh subagent (Roles says how); "
                "it already has your context, so state only the step and the result you need",
            }
        if fact == "bulk-output":
            return 0, {
                "rule": number,
                "route": ["log-reader"],
                "note": "give it the command or the file to read and the facts to return; "
                "it runs on a small model, so check what you act on",
            }
        if fact == "product-behavior":
            if "splits-by-context" in given:
                return 0, {"rule": number, "route": ["feature-developer"], "note": "it writes the tests for its logic"}
            return 0, {"rule": number, "route": ["main"], "note": "implement it yourself, with its tests"}
        return 0, {"rule": number, "route": ["fast-worker"], "note": "the outcome is fully specified"}

    return 0, {"rule": "default", "route": ["main"], "note": "no rule matches; do it yourself"}


def search(facts: list[str]) -> tuple[int, dict]:
    if len(facts) != 1 or facts[0] not in SEARCH:
        raise BadInput(f"search takes exactly one of {list(SEARCH)}")
    return 0, {"rule": "search", "route": [SEARCH[facts[0]]], "note": ""}


def advisor(args: list[str]) -> tuple[int, dict]:
    if len(args) != 3 or args[1] != "--consults":
        raise BadInput("usage: route.py advisor EVENT --consults N")
    event, raw = args[0], args[2]
    if not raw.isdigit():
        raise BadInput(f"--consults must be a whole number, got {raw!r}")
    consults = int(raw)
    if event in ADVISOR_NEVER:
        return 0, {"rule": "advisor", "route": [], "note": "do not consult the advisor for this"}
    if event not in ADVISOR_ALWAYS:
        raise BadInput(f"unknown event {event!r}; known: {list(ADVISOR_ALWAYS + ADVISOR_NEVER)}")
    if consults >= ADVISOR_BUDGET:
        return 1, {
            "rule": "advisor",
            "route": ["user"],
            "note": f"{consults} consults already made; the limit is {ADVISOR_BUDGET} per task, so ask the user first",
        }
    note = f"consult {consults + 1} of {ADVISOR_BUDGET}"
    if event == "repeat-error":
        # Cheaper steps first: a check that reproduces the error, then more effort, then a stronger model.
        note += "; first make sure a test or script reproduces the error"
    return 0, {"rule": "advisor", "route": ["advisor"], "note": note}


def main(argv: list[str]) -> int:
    try:
        if not argv:
            raise BadInput("usage: route.py step|search|advisor ...")
        kind, rest = argv[0], argv[1:]
        if kind == "step":
            code, result = step(rest)
        elif kind == "search":
            code, result = search(rest)
        elif kind == "advisor":
            code, result = advisor(rest)
        else:
            raise BadInput(f"unknown kind {kind!r}; use step, search, or advisor")
    except BadInput as e:
        print(f"route: {e}", file=sys.stderr)
        return 2
    print(json.dumps(result))
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
