# Level 4 — explainer video

Read this file only at level 4. It turns the level 3 steps into a narrated MP4.
Paths in this file are relative to this skill's directory, unless they start with `~`.

## Setup (macOS only)
- Venv: `~/.venvs/explain-video` (Python 3.13, Manim 0.22.0, pytest). Keep it outside the skill
  directory: a plugin update replaces that directory.
  If the venv is somewhere else, set `EXPLAIN_VIDEO_PYTHON` to its Python. The tests read it.
- Homebrew: `ffmpeg`, `cairo`, `pango`, `pkg-config`, `python@3.13`.
- Voice: macOS `say -v Yuna` (offline). No LaTeX: `MathTex` and `Tex` do not work. Use `Text` or `MarkupText`.
- If the venv is missing, recreate it:
  ```
  /opt/homebrew/bin/python3.13 -m venv ~/.venvs/explain-video
  ~/.venvs/explain-video/bin/pip install --only-binary=:all: --no-binary=pycairo,srt manim==0.22.0 'pillow>=13' pytest
  ```
  `pycairo` and `srt` ship only as source on PyPI, so they build locally.
  `pillow>=13` is a security floor: Pillow 12.x has known image-decoder vulnerabilities, and manim 0.22.0 accepts any Pillow 11.0 or later.
  For an existing venv, run `~/.venvs/explain-video/bin/pip install -U 'pillow>=13'`.

## Files
```
scripts/video/
  build.py       script.json + scenes.py -> out/video.mp4
  narrated.py    NarratedScene: Korean font, pads each scene to its narration
  example/       a 3-scene sample (script.json + scenes.py) to copy from
  tests/         unit tests + one end-to-end test (marked slow)
```

## Procedure
1. Make a work directory outside the skill directory, for example `<temp dir>/video/<topic>/`.
   In Claude Code, use the session scratchpad.
2. Write `script.json`. Use the level 3 steps: one step = one scene, same names, same order.
   - `id`: a Python class name, for example `S2_Request`.
   - `narration`: spoken Korean, one to three sentences. The narration sets the scene length.
     Write it for the ear, not for reading:
     - Use 해요체 ("보내요", "조회해요"), not "~입니다" at the end of every sentence.
     - Join very short sentences with a connective ("~하면", "~하고"). This is the one exception
       to the one-point-per-sentence rule: a chain of short sentences sounds choppy when spoken.
     - Put a comma where a speaker would pause.
     - Say the same words that the boxes and arrows show (STE: one term for one concept).
   - `visual`: one sentence that says what the scene shows.
   - Optional: `voice` (default `Yuna`), `max_seconds` (default 180).
3. Write `scenes.py`. Copy the structure of `scripts/video/example/scenes.py`:
   - One `NarratedScene` subclass per scene id: `from narrated import NarratedScene`.
   - One shared layout helper, so every scene puts the same box in the same place.
   - Do not end `construct()` with a long `self.wait()`. `NarratedScene` pads the scene to the narration.
   - If a scene shows the result of an earlier scene, `self.add()` that state first, then animate the change.
4. Run the build:
   ```
   ~/.venvs/explain-video/bin/python scripts/video/build.py <work_dir>
   ```
   It prints audio and video seconds for each scene. Exit 1 prints the reason.
5. If the build reports "over the ... cap", shorten the narration of the listed scenes, then run it again.
6. Check the picture before you send the video. Take the last frame of each scene and read the PNGs:
   ```
   ffmpeg -v error -y -sseof -0.1 -i <work_dir>/build/media/videos/scenes/720p30/<id>.mp4 -frames:v 1 <id>.png
   ```
   Look for text that overlaps, leaves the frame, or shows empty boxes (missing glyphs).
7. Send `<work_dir>/out/video.mp4` with the agent's file-delivery tool.
   In Claude Code, this is `SendUserFile` with `display: "render"`.
   If the agent cannot deliver files, give the user the path and `open <path>`.

## If something fails
- `say` voice error: list voices with `say -v '?' | grep ko_KR`.
- `No module named manim`: run `build.py` with the venv Python, not the system Python.
- `KeyError: 'EXPLAIN_VIDEO_DURATIONS'`: you ran `manim` on `scenes.py` directly. Run it through `build.py`.
- Changes to `build.py` or `narrated.py`: run the tests from `scripts/video/`:
  `PYTHONDONTWRITEBYTECODE=1 ~/.venvs/explain-video/bin/python -m pytest -q -p no:cacheprovider`
  The wrappers `tests/unit/video_build_test.sh` and `tests/integration/video_e2e_test.sh` run the same suite.
