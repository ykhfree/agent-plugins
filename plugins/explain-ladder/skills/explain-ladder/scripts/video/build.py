"""Build a narrated explainer video from script.json and scenes.py.

Usage: ~/.venvs/explain-video/bin/python build.py WORK_DIR

WORK_DIR holds:
  script.json  {"title", "scenes": [{"id", "narration", "visual"}], "voice"?, "max_seconds"?}
  scenes.py    one NarratedScene subclass per scene id (from narrated import NarratedScene)

Narration drives timing: each scene's audio is made first,
and the scene is padded to the audio length.
Output: WORK_DIR/out/video.mp4. Intermediate files: WORK_DIR/build/.
"""

import ast
import json
import math
import os
import re
import subprocess
import sys
from pathlib import Path

DEFAULT_VOICE = "Yuna"
DEFAULT_MAX_SECONDS = 180
DURATIONS_ENV = "EXPLAIN_VIDEO_DURATIONS"
ID_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
SCRIPT_DIR = Path(__file__).resolve().parent


class BuildError(Exception):
    pass


def scene_classes_in(source: str) -> set[str]:
    """Return the names of top-level classes in scenes.py source."""
    return {node.name for node in ast.parse(source).body if isinstance(node, ast.ClassDef)}


def validate_script(data: object, scene_classes: set[str]) -> list[str]:
    """Return every problem in script.json data. An empty list means valid."""
    if not isinstance(data, dict):
        return ["script.json must be a JSON object"]
    errors = []
    scenes = data.get("scenes")
    if not isinstance(scenes, list) or not scenes:
        return ["'scenes' must be a non-empty list"]
    seen = set()
    for index, scene in enumerate(scenes):
        where = f"scenes[{index}]"
        if not isinstance(scene, dict):
            errors.append(f"{where}: must be an object")
            continue
        scene_id = scene.get("id")
        if not isinstance(scene_id, str) or not ID_PATTERN.match(scene_id):
            errors.append(f"{where}: 'id' must be a Python class name, got {scene_id!r}")
        elif scene_id in seen:
            errors.append(f"{where}: duplicate id {scene_id!r}")
        elif scene_id not in scene_classes:
            errors.append(f"{where}: scenes.py has no class {scene_id!r}")
        else:
            seen.add(scene_id)
        for field in ("narration", "visual"):
            value = scene.get(field)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"{where}: '{field}' must be a non-empty string")
    max_seconds = data.get("max_seconds", DEFAULT_MAX_SECONDS)
    if isinstance(max_seconds, bool) or not isinstance(max_seconds, (int, float)) or max_seconds <= 0:
        errors.append(f"'max_seconds' must be a positive number, got {max_seconds!r}")
    return errors


def pad_seconds(narration_seconds: float, elapsed_seconds: float, frame_rate: float) -> float:
    """Return the wait that makes a scene at least as long as its narration.

    The wait is rounded up to whole frames, so the video never cuts the audio.
    Returns 0 if the animations already last longer than the narration.
    """
    missing = narration_seconds - elapsed_seconds
    if missing <= 0:
        return 0.0
    # Round to 6 places first: float noise must not add a whole extra frame.
    return math.ceil(round(missing * frame_rate, 6)) / frame_rate


def check_cap(durations: dict[str, float], max_seconds: float) -> str | None:
    """Return an error with a per-scene breakdown if the narration is too long."""
    total = sum(durations.values())
    if total <= max_seconds:
        return None
    lines = [f"Narration is {total:.1f} s, over the {max_seconds:g} s cap. Shorten these scenes:"]
    for scene_id, seconds in sorted(durations.items(), key=lambda item: -item[1]):
        lines.append(f"  {scene_id}: {seconds:.1f} s")
    return "\n".join(lines)


def tts_cmd(voice: str, text_file: Path, out: Path) -> list[str]:
    return ["say", "-v", voice, "-f", str(text_file), "-o", str(out)]


def probe_cmd(media: Path) -> list[str]:
    return ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(media)]


def render_cmd(work_dir: Path, scene_id: str) -> list[str]:
    # -qm renders 1280x720 at 30 fps.
    return [
        sys.executable, "-m", "manim", "-qm", "--format", "mp4",
        "--media_dir", str(work_dir / "build" / "media"),
        str(work_dir / "scenes.py"), scene_id,
    ]


def mux_cmd(video: Path, audio: Path, out: Path) -> list[str]:
    # apad + -shortest: silence fills the audio up to the video length.
    return [
        "ffmpeg", "-v", "error", "-y", "-i", str(video), "-i", str(audio),
        "-c:v", "copy", "-c:a", "aac", "-af", "apad", "-shortest", str(out),
    ]


def concat_list(parts: list[Path]) -> str:
    """Return an ffmpeg concat-demuxer list. Single quotes in paths are escaped."""
    return "".join("file '" + str(part).replace("'", "'\\''") + "'\n" for part in parts)


def concat_cmd(list_file: Path, out: Path) -> list[str]:
    return ["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(list_file), "-c", "copy", str(out)]


def run(cmd: list[str], **kwargs) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True, **kwargs)
    if result.returncode != 0:
        raise BuildError(f"Command failed ({result.returncode}): {' '.join(cmd)}\n{result.stderr[-2000:]}")
    return result.stdout


def probe_seconds(media: Path) -> float:
    return float(run(probe_cmd(media)).strip())


def find_rendered(work_dir: Path, scene_id: str) -> Path:
    matches = list((work_dir / "build" / "media").rglob(f"{scene_id}.mp4"))
    if len(matches) != 1:
        raise BuildError(f"Expected one rendered {scene_id}.mp4, found {len(matches)}")
    return matches[0]


def build(work_dir: Path) -> Path:
    data = json.loads((work_dir / "script.json").read_text(encoding="utf-8"))
    classes = scene_classes_in((work_dir / "scenes.py").read_text(encoding="utf-8"))
    errors = validate_script(data, classes)
    if errors:
        raise BuildError("script.json is invalid:\n  " + "\n  ".join(errors))

    voice = data.get("voice", DEFAULT_VOICE)
    build_dir = work_dir / "build"
    build_dir.mkdir(parents=True, exist_ok=True)

    # 1. Narration first: its length sets each scene's length.
    durations = {}
    for scene in data["scenes"]:
        text_file = build_dir / f"{scene['id']}.txt"
        audio = build_dir / f"{scene['id']}.aiff"
        text_file.write_text(scene["narration"], encoding="utf-8")
        run(tts_cmd(voice, text_file, audio))
        durations[scene["id"]] = probe_seconds(audio)

    cap_error = check_cap(durations, data.get("max_seconds", DEFAULT_MAX_SECONDS))
    if cap_error:
        raise BuildError(cap_error)

    durations_file = build_dir / "durations.json"
    durations_file.write_text(json.dumps(durations), encoding="utf-8")

    # 2. Render each scene, padded to its narration. 3. Mux audio per scene.
    env = {
        **os.environ,
        DURATIONS_ENV: str(durations_file),
        # Keep __pycache__ out of the skill directory.
        "PYTHONDONTWRITEBYTECODE": "1",
        "PYTHONPATH": os.pathsep.join(filter(None, [str(SCRIPT_DIR), os.environ.get("PYTHONPATH")])),
    }
    parts = []
    for scene_id, audio_seconds in durations.items():
        run(render_cmd(work_dir, scene_id), cwd=work_dir, env=env)
        video = find_rendered(work_dir, scene_id)
        video_seconds = probe_seconds(video)
        part = build_dir / f"{scene_id}.muxed.mp4"
        run(mux_cmd(video, build_dir / f"{scene_id}.aiff", part))
        parts.append(part)
        print(f"{scene_id}: audio {audio_seconds:.2f} s, video {video_seconds:.2f} s")

    # 4. Join the scenes.
    list_file = build_dir / "concat.txt"
    list_file.write_text(concat_list(parts), encoding="utf-8")
    out = work_dir / "out" / "video.mp4"
    out.parent.mkdir(exist_ok=True)
    run(concat_cmd(list_file, out))
    print(f"Total: {probe_seconds(out):.2f} s -> {out}")
    return out


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        build(Path(sys.argv[1]).resolve())
    except BuildError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
