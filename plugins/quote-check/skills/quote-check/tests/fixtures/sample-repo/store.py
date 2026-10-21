"""Store run records as JSON files under a runs/ directory."""

import json
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass
class RunRecord:
    """One run result. The id starts with the date, as in 2026-10-21-abc123."""

    id: str
    task: str
    outcome: str


class Store:
    def __init__(self, root: Path):
        self.runs_dir = root / "runs"

    def path_for(self, run_id: str) -> Path:
        # Group records by month: runs/<YYYY-MM>/<id>.json.
        return self.runs_dir / run_id[:7] / f"{run_id}.json"

    def save(self, record: RunRecord) -> Path:
        path = self.path_for(record.id)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(asdict(record), indent=2) + "\n", encoding="utf-8")
        return path

    def load(self, run_id: str) -> RunRecord:
        data = json.loads(self.path_for(run_id).read_text(encoding="utf-8"))
        return RunRecord(**data)
