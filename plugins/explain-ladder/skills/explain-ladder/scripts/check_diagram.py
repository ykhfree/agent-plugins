#!/usr/bin/env python3
"""Check a level 2 ASCII diagram against the explain-ladder rules.

Usage:  check_diagram.py [FILE]    (reads stdin when FILE is omitted)

Input:  the diagram text. If the first and last non-empty lines are code
        fences (```), they are removed before the check.
Rules:  every character is printable ASCII or a letter or digit of any
        language (no tabs, box-drawing characters, or Unicode arrows),
        every line is 72 columns or narrower (a wide character such as
        Hangul counts as 2 columns, as a terminal shows it),
        the diagram has 3 to 9 boxes.
        A box is a top edge "+--...--+" with "|" under both corners.
Output: "OK: <n> boxes, <m> lines" on stdout, exit 0.
        One "line <l>: ..." or "diagram: ..." line per violation on stdout, exit 1.
        Usage or read error on stderr, exit 2.
"""

import re
import sys
import unicodedata

MAX_WIDTH = 72
MIN_BOXES = 3
MAX_BOXES = 9
EDGE = re.compile(r"\+-+\+")


def strip_fences(lines: list[str]) -> list[str]:
    content = [i for i, line in enumerate(lines) if line.strip()]
    if len(content) >= 2:
        first, last = content[0], content[-1]
        if lines[first].lstrip().startswith("```") and lines[last].strip() == "```":
            return lines[first + 1:last]
    return lines


def is_allowed(char: str) -> bool:
    return " " <= char <= "~" or unicodedata.category(char)[0] in "LN"


def cells(line: str) -> str:
    """Return the line as a terminal shows it: a wide character fills 2 columns."""
    return "".join(char + " " if unicodedata.east_asian_width(char) in "WF" else char for char in line)


def count_boxes(lines: list[str]) -> int:
    grid = [cells(line) for line in lines]

    def char_at(row: int, col: int) -> str:
        return grid[row][col] if 0 <= row < len(grid) and col < len(grid[row]) else ""

    boxes = 0
    for row, line in enumerate(grid):
        for edge in EDGE.finditer(line):
            left, right = edge.start(), edge.end() - 1
            # A top edge has "|" below both corners. A shared edge of stacked boxes counts once, as the lower box's top.
            if char_at(row + 1, left) == "|" and char_at(row + 1, right) == "|":
                boxes += 1
    return boxes


def check(lines: list[str]) -> tuple[int, list[str]]:
    """Return the box count and every rule violation. No violations means the diagram passes."""
    problems = []
    for number, line in enumerate(lines, start=1):
        for position, char in enumerate(line, start=1):
            if not is_allowed(char):
                problems.append(f"line {number}: character {position} is U+{ord(char):04X}, use ASCII symbols only")
                break
        width = len(cells(line))
        if width > MAX_WIDTH:
            problems.append(f"line {number}: {width} columns, limit is {MAX_WIDTH}")
    boxes = count_boxes(lines)
    if not MIN_BOXES <= boxes <= MAX_BOXES:
        problems.append(f"diagram: {boxes} boxes, the limit is {MIN_BOXES} to {MAX_BOXES}"
                        ' (a box counts only if "|" is under both corners of its top edge)')
    return boxes, problems


def main() -> int:
    if len(sys.argv) > 2:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        if len(sys.argv) == 2:
            with open(sys.argv[1], encoding="utf-8") as file:
                text = file.read()
        else:
            text = sys.stdin.read()
    except (OSError, UnicodeDecodeError) as error:
        print(f"cannot read input: {error}", file=sys.stderr)
        return 2
    lines = strip_fences(text.splitlines())
    boxes, problems = check(lines)
    if problems:
        print("\n".join(problems))
        return 1
    print(f"OK: {boxes} boxes, {len(lines)} lines")
    return 0


if __name__ == "__main__":
    sys.exit(main())
