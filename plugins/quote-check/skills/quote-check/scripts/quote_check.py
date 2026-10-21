#!/usr/bin/env python3
"""Check that each quote a claim rests on appears verbatim in its file.

Input:  a JSON list of {"claim", "file", "quote"} objects, from the file named by
        the only argument, or from stdin when the argument is "-" or absent.
        A relative `file` is resolved against the current directory.
Output: one JSON object on stdout, {"claims": [...]}, one item per input claim,
        in input order, each with "claim", "file" and "verdict":
          found        + "lines" ("first-last", 1-based) and "section"
                         (the quoted lines plus CONTEXT_LINES on each side)
          fabricated   the quote is not in the file
          file_missing the file does not exist
        The match collapses whitespace and folds curly quotes, so a quote may
        span wrapped lines. Nothing here judges whether the claim is true.
Exit:   0 every quote found, 1 any fabricated or file_missing,
        2 bad input (message on stderr as "quote_check: <message>").
"""

import bisect
import json
import re
import sys
from pathlib import Path

CONTEXT_LINES = 15
QUOTE_FOLD = str.maketrans({"“": '"', "”": '"', "‘": "'", "’": "'"})


class InputError(Exception):
    pass


def normalize(text: str) -> str:
    """Collapse whitespace and fold curly quotes, so a quote matches across line wraps."""
    return re.sub(r"\s+", " ", text.translate(QUOTE_FOLD)).strip()


def locate_quote(text: str, quote: str) -> tuple[int, int] | None:
    """1-based (first, last) line numbers of the first match of `quote`, or None."""
    needle = normalize(quote)
    if not needle:
        return None
    starts, numbers, parts, pos = [], [], [], 0
    for number, line in enumerate(text.splitlines(), 1):
        norm = normalize(line)
        if not norm:
            continue
        starts.append(pos)
        numbers.append(number)
        parts.append(norm)
        pos += len(norm) + 1  # +1 for the joining space
    hit = " ".join(parts).find(needle)
    if hit < 0:
        return None
    first = bisect.bisect_right(starts, hit) - 1
    last = bisect.bisect_right(starts, hit + len(needle) - 1) - 1
    return numbers[first], numbers[last]


def section(text: str, first: int, last: int) -> str:
    """Lines first..last (1-based) plus CONTEXT_LINES of context on each side."""
    lines = text.splitlines()
    return "\n".join(lines[max(0, first - 1 - CONTEXT_LINES) : last + CONTEXT_LINES])


def check(claim: dict) -> dict:
    out = {"claim": claim["claim"], "file": claim["file"]}
    path = Path(claim["file"])
    if not path.is_file():
        return {**out, "verdict": "file_missing"}
    text = path.read_text(encoding="utf-8", errors="replace")
    span = locate_quote(text, claim["quote"])
    if span is None:
        return {**out, "verdict": "fabricated"}
    first, last = span
    return {**out, "verdict": "found", "lines": f"{first}-{last}", "section": section(text, first, last)}


def load(argv: list[str]) -> list[dict]:
    if len(argv) > 1:
        raise InputError("usage: quote_check.py [claims.json | -]")
    source = argv[0] if argv else "-"
    try:
        raw = sys.stdin.read() if source == "-" else Path(source).read_text(encoding="utf-8")
        claims = json.loads(raw)
    except (OSError, json.JSONDecodeError) as e:
        raise InputError(f"cannot read claims: {e}") from e
    if not isinstance(claims, list) or not all(
        isinstance(c, dict) and all(isinstance(c.get(k), str) for k in ("claim", "file", "quote")) for c in claims
    ):
        raise InputError('claims must be a JSON list of {"claim", "file", "quote"} string objects')
    return claims


def main(argv: list[str]) -> int:
    try:
        claims = load(argv)
    except InputError as e:
        print(f"quote_check: {e}", file=sys.stderr)
        return 2
    results = [check(c) for c in claims]
    print(json.dumps({"claims": results}, ensure_ascii=False))
    return 0 if all(r["verdict"] == "found" for r in results) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
