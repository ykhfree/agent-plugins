import json
import subprocess
import sys
from pathlib import Path

import pytest

import build
from build import (
    BuildError,
    check_cap,
    concat_list,
    mux_cmd,
    pad_seconds,
    render_cmd,
    scene_classes_in,
    validate_script,
)


def valid_script(**overrides):
    data = {
        "title": "Test",
        "scenes": [
            {"id": "Intro", "narration": "안녕하세요.", "visual": "A box appears."},
            {"id": "Flow", "narration": "요청이 갑니다.", "visual": "An arrow moves."},
        ],
    }
    data.update(overrides)
    return data


CLASSES = {"Intro", "Flow"}


class TestSceneClassesIn:
    def test_returns_top_level_classes_only(self):
        source = (
            "class Intro: pass\n"
            "def helper():\n    class Hidden: pass\n"
            "class Flow:\n    class Inner: pass\n"
        )
        assert scene_classes_in(source) == {"Intro", "Flow"}

    def test_empty_source_has_no_classes(self):
        assert scene_classes_in("") == set()


class TestValidateScript:
    def test_valid_script_has_no_errors(self):
        assert validate_script(valid_script(), CLASSES) == []

    def test_non_object_is_rejected(self):
        assert validate_script([], CLASSES) == ["script.json must be a JSON object"]

    @pytest.mark.parametrize("scenes", [None, [], "Intro"])
    def test_scenes_must_be_non_empty_list(self, scenes):
        assert validate_script(valid_script(scenes=scenes), CLASSES) == ["'scenes' must be a non-empty list"]

    @pytest.mark.parametrize("bad_id", ["1Intro", "my-scene", "", None, 3])
    def test_id_must_be_class_name(self, bad_id):
        data = valid_script()
        data["scenes"][0]["id"] = bad_id
        errors = validate_script(data, CLASSES)
        assert len(errors) == 1
        assert "'id' must be a Python class name" in errors[0]

    def test_duplicate_id_is_rejected(self):
        data = valid_script()
        data["scenes"][1]["id"] = "Intro"
        assert validate_script(data, CLASSES) == ["scenes[1]: duplicate id 'Intro'"]

    def test_id_without_scene_class_is_rejected(self):
        assert validate_script(valid_script(), {"Intro"}) == ["scenes[1]: scenes.py has no class 'Flow'"]

    @pytest.mark.parametrize("field", ["narration", "visual"])
    @pytest.mark.parametrize("value", [None, "", "   \n", 5])
    def test_text_fields_must_be_non_empty(self, field, value):
        data = valid_script()
        data["scenes"][0][field] = value
        assert validate_script(data, CLASSES) == [f"scenes[0]: '{field}' must be a non-empty string"]

    def test_non_object_scene_is_rejected(self):
        data = valid_script()
        data["scenes"][1] = "Flow"
        assert validate_script(data, CLASSES) == ["scenes[1]: must be an object"]

    @pytest.mark.parametrize("max_seconds", [0, -5, "180", True])
    def test_max_seconds_must_be_positive_number(self, max_seconds):
        errors = validate_script(valid_script(max_seconds=max_seconds), CLASSES)
        assert errors == [f"'max_seconds' must be a positive number, got {max_seconds!r}"]

    def test_reports_every_problem_at_once(self):
        data = valid_script(max_seconds=0)
        data["scenes"][0]["narration"] = ""
        data["scenes"][1]["id"] = "Intro"
        assert len(validate_script(data, CLASSES)) == 3


class TestPadSeconds:
    def test_pads_to_narration_rounded_up_to_whole_frames(self):
        # 1.01 s missing = 30.3 frames -> 31 frames.
        assert pad_seconds(2.01, 1.0, 30) == pytest.approx(31 / 30)

    def test_exact_frame_count_adds_no_extra_frame(self):
        # 0.1 + 0.2 = 0.30000000000000004; 9.000000000000002 frames must stay 9.
        assert pad_seconds(0.1 + 0.2, 0.0, 30) == pytest.approx(9 / 30)

    def test_no_wait_when_animation_is_longer(self):
        assert pad_seconds(1.0, 2.5, 30) == 0.0

    def test_no_wait_when_lengths_are_equal(self):
        assert pad_seconds(2.0, 2.0, 30) == 0.0

    def test_uses_given_frame_rate(self):
        # 0.5 s at 60 fps = 30 frames exactly.
        assert pad_seconds(0.5, 0.0, 60) == pytest.approx(0.5)


class TestCheckCap:
    def test_under_cap_passes(self):
        assert check_cap({"Intro": 60.0, "Flow": 60.0}, 180) is None

    def test_exactly_at_cap_passes(self):
        assert check_cap({"Intro": 100.0, "Flow": 80.0}, 180) is None

    def test_over_cap_lists_scenes_longest_first(self):
        message = check_cap({"Intro": 50.0, "Flow": 140.0}, 180)
        assert message.splitlines() == [
            "Narration is 190.0 s, over the 180 s cap. Shorten these scenes:",
            "  Flow: 140.0 s",
            "  Intro: 50.0 s",
        ]


class TestCommands:
    def test_mux_pads_audio_and_stops_at_video_end(self):
        cmd = mux_cmd(Path("v.mp4"), Path("a.aiff"), Path("o.mp4"))
        assert cmd[:2] == ["ffmpeg", "-v"]
        assert cmd[cmd.index("-af") + 1] == "apad"
        assert "-shortest" in cmd
        assert cmd[cmd.index("-c:v") + 1] == "copy"
        assert cmd[-1] == "o.mp4"

    def test_render_uses_720p_and_the_venv_python(self, tmp_path):
        cmd = render_cmd(tmp_path, "Intro")
        assert cmd[:3] == [sys.executable, "-m", "manim"]
        assert "-qm" in cmd
        assert cmd[-2:] == [str(tmp_path / "scenes.py"), "Intro"]
        assert cmd[cmd.index("--media_dir") + 1] == str(tmp_path / "build" / "media")

    def test_concat_list_escapes_single_quotes(self):
        text = concat_list([Path("/a/b.mp4"), Path("/x/it's.mp4")])
        assert text == "file '/a/b.mp4'\nfile '/x/it'\\''s.mp4'\n"


class TestBuildFailsEarly:
    @pytest.fixture
    def no_subprocess(self, monkeypatch):
        def fail(*args, **kwargs):
            raise AssertionError(f"subprocess called: {args[0]}")

        monkeypatch.setattr(subprocess, "run", fail)

    def test_invalid_script_stops_before_tts(self, tmp_path, no_subprocess):
        data = valid_script()
        data["scenes"][0]["narration"] = ""
        (tmp_path / "script.json").write_text(json.dumps(data), encoding="utf-8")
        (tmp_path / "scenes.py").write_text("class Intro: pass\nclass Flow: pass\n", encoding="utf-8")
        with pytest.raises(BuildError, match="'narration' must be a non-empty string"):
            build.build(tmp_path)
        assert not (tmp_path / "build").exists()

    def test_main_without_work_dir_prints_usage(self, monkeypatch, capsys):
        monkeypatch.setattr(sys, "argv", ["build.py"])
        assert build.main() == 2
        assert "Usage:" in capsys.readouterr().err
