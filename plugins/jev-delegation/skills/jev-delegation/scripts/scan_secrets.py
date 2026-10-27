#!/usr/bin/env python3
"""Scan text that is about to go to jev for content that looks like a real secret.

jev itself refuses only secret-like file names (.env, *.pem, ...). This scan reads the content.

Input:  argv: one or more paths, or "-" for stdin. A directory is walked. The walk skips the
        directories in SKIP_DIRS and scans every other file, hidden ones included, because
        `jev search` in a git work tree sends hidden files such as .github/ too.
Output: one line per hit on stdout, "<path>:<line>: <pattern>". The matched value is never
        printed. Image and other binary files cannot be scanned and are listed as
        "<path>: unscanned (binary)".
Exit:   0 no hits, 1 at least one hit, 2 bad input (message on stderr as "scan_secrets: <message>").
"""

import os
import re
import sys

SKIP_DIRS = {".git", "node_modules", "__pycache__", ".venv", "venv", "build", "dist", ".gradle", ".idea"}
SNIFF_BYTES = 8192

# Order matters only for the label: a line reports each pattern name once.
PATTERNS = [
    ("private-key", re.compile(r"-----BEGIN (?:[A-Z]+ )*PRIVATE KEY(?: BLOCK)?-----")),
    ("aws-access-key-id", re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("anthropic-api-key", re.compile(r"\bsk-ant-[A-Za-z0-9_-]{20,}")),
    ("openai-api-key", re.compile(r"\bsk-(?!ant-)(?:proj-)?[A-Za-z0-9_-]{20,}")),
    ("github-token", re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,})")),
    ("slack-token", re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}")),
    ("google-api-key", re.compile(r"\bAIza[0-9A-Za-z_-]{35}")),
    ("jwt", re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}")),
    # NAME = value, as in .env files and config. The value must end the assignment, so
    # code such as `token = request.headers.get(...)` or `os.environ["X"]` does not match.
    (
        "secret-assignment",
        re.compile(
            r"(?i)\b[a-z0-9_]*(?:secret|token|password|passwd|api_?key|private_?key)[a-z0-9_]*"
            r"[\"']?\s*[:=]\s*[\"']?[A-Za-z0-9_\-+/=.@~!%^&*]{8,}[\"']?\s*(?:[,;]|#.*)?$"
        ),
    ),
]


class BadInput(Exception):
    pass


def is_binary(path: str) -> bool:
    with open(path, "rb") as f:
        return b"\0" in f.read(SNIFF_BYTES)


def files_under(root: str) -> list[str]:
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
        found += [os.path.join(dirpath, f) for f in sorted(filenames)]
    return found


def scan_text(label: str, text: str) -> list[str]:
    hits = []
    for number, line in enumerate(text.splitlines(), 1):
        for name, pattern in PATTERNS:
            if pattern.search(line):
                hits.append(f"{label}:{number}: {name}")
    return hits


def scan(paths: list[str]) -> tuple[list[str], list[str]]:
    """(hit lines, unscanned lines)."""
    hits, unscanned = [], []
    for path in paths:
        if path == "-":
            hits += scan_text("<stdin>", sys.stdin.read())
            continue
        if not os.path.exists(path):
            raise BadInput(f"no such path: {path}")
        for f in files_under(path) if os.path.isdir(path) else [path]:
            if is_binary(f):
                unscanned.append(f"{f}: unscanned (binary)")
                continue
            with open(f, encoding="utf-8", errors="replace") as handle:
                hits += scan_text(f, handle.read())
    return hits, unscanned


def main(argv: list[str]) -> int:
    try:
        if not argv:
            raise BadInput("usage: scan_secrets.py PATH... (- for stdin)")
        hits, unscanned = scan(argv)
    except (BadInput, OSError) as e:
        print(f"scan_secrets: {e}", file=sys.stderr)
        return 2
    for line in hits + unscanned:
        print(line)
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
