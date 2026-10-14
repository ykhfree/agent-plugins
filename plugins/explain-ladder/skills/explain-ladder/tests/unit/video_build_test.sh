#!/usr/bin/env bash
# Unit tests of the level 4 video builder: runs the pytest suite in scripts/video/
# without the slow tests. Needs a Python with pytest; set EXPLAIN_VIDEO_PYTHON to override.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
py="${EXPLAIN_VIDEO_PYTHON:-$HOME/.venvs/explain-video/bin/python}"
if [[ ! -x "$py" ]]; then
  echo "no video Python at $py: create the venv in video.md or set EXPLAIN_VIDEO_PYTHON" >&2
  exit 1
fi
cd "$here/../../scripts/video"
PYTHONDONTWRITEBYTECODE=1 "$py" -m pytest -q -p no:cacheprovider -m "not slow"
