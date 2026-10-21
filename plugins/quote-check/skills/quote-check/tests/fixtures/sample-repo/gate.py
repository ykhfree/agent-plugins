"""Decide whether a new learning is worth saving to a memory store.

A scorer returns one probability per label. The gate compares them with a
band: below the lower bound counts as "no", above the upper bound as "yes".
"""

from dataclasses import dataclass

# Probabilities inside this band are treated as unsure.
UNSURE_BAND = (0.3, 0.7)

LABELS = ("reusable", "stable", "actionable", "noise")
WANTED = ("reusable", "stable", "actionable")


@dataclass
class Decision:
    action: str
    reason: str


def _missing(scores: dict[str, float]) -> list[str]:
    return [label for label in LABELS if label not in scores]


def _describe(scores: dict[str, float]) -> str:
    return ", ".join(f"{label}={scores[label]:.2f}" for label in LABELS)


def _check_range(scores: dict[str, float]) -> None:
    for label, p in scores.items():
        if not 0.0 <= p <= 1.0:
            raise ValueError(f"{label} score out of range: {p}")


def decide(scores: dict[str, float], *, conflict: bool, duplicate: bool) -> Decision:
    """Return "save", "skip", or "ask" for one candidate learning."""
    missing = _missing(scores)
    if missing:
        raise ValueError(f"missing scores: {', '.join(missing)}")
    _check_range(scores)
    if conflict:
        return Decision("ask", "conflicts with a stored learning")
    if duplicate:
        return Decision("skip", "duplicates a stored learning")

    lo, hi = UNSURE_BAND
    wanted = [scores[label] for label in WANTED]
    if any(p <= lo for p in wanted) or scores["noise"] >= hi:
        return Decision("skip", _describe(scores))
    if all(p >= hi for p in wanted):
        return Decision("save", _describe(scores))
    return Decision("ask", _describe(scores))
