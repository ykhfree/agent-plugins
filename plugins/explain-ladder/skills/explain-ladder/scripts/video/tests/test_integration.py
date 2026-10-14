"""End-to-end build with real say, manim and ffmpeg."""

import json
import subprocess
from pathlib import Path

import pytest

import build
from build import BuildError, probe_seconds

pytestmark = pytest.mark.slow

FRAME = 1 / 30

# Short scene: the narration is longer, so the video is padded.
# Long scene: the animation (3 s) is longer, so silence fills the audio.
SCENES_PY = """
from manim import Create, RoundedRectangle, Text, Write
from narrated import NarratedScene

class Short(NarratedScene):
    def construct(self):
        self.play(Write(Text("요청")), run_time=0.5)

class Long(NarratedScene):
    def construct(self):
        self.play(Create(RoundedRectangle(width=3, height=1)), run_time=3)
"""


def write_project(work_dir: Path, **overrides):
    script = {
        "title": "Integration",
        "scenes": [
            {"id": "Short", "narration": "클라이언트가 서버로 요청을 보내고 응답을 기다립니다.", "visual": "Word appears."},
            {"id": "Long", "narration": "끝.", "visual": "Box is drawn."},
        ],
    }
    script.update(overrides)
    (work_dir / "script.json").write_text(json.dumps(script, ensure_ascii=False), encoding="utf-8")
    (work_dir / "scenes.py").write_text(SCENES_PY, encoding="utf-8")


def stream_types(media: Path) -> list[str]:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "stream=codec_type", "-of", "csv=p=0", str(media)],
        capture_output=True, text=True, check=True,
    ).stdout
    return out.split()


def test_video_length_follows_narration_or_animation(tmp_path):
    write_project(tmp_path)
    out = build.build(tmp_path)

    durations = json.loads((tmp_path / "build" / "durations.json").read_text())
    assert durations["Short"] > 0.5, "the test needs narration longer than the Short animation"
    assert durations["Long"] < 3, "the test needs narration shorter than the Long animation"

    # Each scene lasts max(narration, animation), rounded up to whole frames.
    expected = durations["Short"] + 3.0
    assert probe_seconds(out) == pytest.approx(expected, abs=4 * FRAME)
    assert probe_seconds(tmp_path / "build" / "Short.muxed.mp4") >= durations["Short"] - FRAME
    assert sorted(stream_types(out)) == ["audio", "video"]


def test_over_cap_fails_before_rendering(tmp_path):
    write_project(tmp_path, max_seconds=0.5)
    with pytest.raises(BuildError, match="over the 0.5 s cap"):
        build.build(tmp_path)
    assert not (tmp_path / "build" / "media").exists()
