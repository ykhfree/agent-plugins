#!/usr/bin/env python3
"""Apply the orchestration-policy rules to facts you have judged about one step.

Input:  argv, one of
          step FACT...                  facts: exact-edit, costly-decision, options-open, undecided,
                                        product-behavior, splits-by-context, fully-specified
          search FACT                   exactly one of: few-calls, locate, trace, why
          advisor EVENT --consults N    EVENT: costly-decision, large-plan, repeat-error, declare-done,
                                        trivial, rephrase; N = advisor consults already made in this task
        SKILL.md defines when each fact or event holds.
Output: one JSON object on stdout, {"rule", "route", "note"}.
        route: the roles to use, in order (main, deep-reasoner, critic, advisor, feature-developer,
        fast-worker, fast-explorer, Explore, user). An empty route means "do not consult".
Exit:   0 follow the route, 1 the policy stops you (no rule matches, or the advisor budget is
        spent and you must ask the user), 2 bad input (message on stderr as "route: <message>").
"""

import json
import sys

ADVISOR_BUDGET = 3

# Step rules in order; the first rule whose fact is given wins.
STEP_FACTS = ("exact-edit", "costly-decision", "undecided", "product-behavior", "fully-specified")
# A modifier changes the outcome of the rule it belongs to.
MODIFIERS = {"options-open": "costly-decision", "splits-by-context": "product-behavior"}

SEARCH = {"few-calls": "main", "locate": "fast-explorer", "trace": "Explore", "why": "deep-reasoner"}
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
        if fact == "product-behavior":
            if "splits-by-context" in given:
                return 0, {"rule": number, "route": ["feature-developer"], "note": "it writes the tests for its logic"}
            return 0, {"rule": number, "route": ["main"], "note": "implement it yourself, with its tests"}
        return 0, {"rule": number, "route": ["fast-worker"], "note": "the outcome is fully specified"}

    return 1, {"rule": None, "route": [], "note": "no routing rule matches; check each fact against SKILL.md again"}


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
    return 0, {"rule": "advisor", "route": ["advisor"], "note": f"consult {consults + 1} of {ADVISOR_BUDGET}"}


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
