"""Base class for scenes rendered by build.py."""

import json
import os

from manim import MarkupText, Scene, Text, config

from build import DURATIONS_ENV, pad_seconds

KOREAN_FONT = "Apple SD Gothic Neo"


class NarratedScene(Scene):
    """A scene that lasts at least as long as its narration.

    The class name must match the scene id in script.json.
    After construct() ends, the scene waits until the narration ends.
    """

    def setup(self):
        Text.set_default(font=KOREAN_FONT)
        MarkupText.set_default(font=KOREAN_FONT)

    def tear_down(self):
        with open(os.environ[DURATIONS_ENV], encoding="utf-8") as file:
            narration = json.load(file)[type(self).__name__]
        wait = pad_seconds(narration, self.time, config.frame_rate)
        if wait > 0:
            self.wait(wait)
