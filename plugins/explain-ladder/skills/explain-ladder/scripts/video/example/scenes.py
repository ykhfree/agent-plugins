"""Example scenes for script.json. One class per scene id, same order."""

from manim import (
    BLUE, DOWN, LEFT, RIGHT, UP, YELLOW,
    Arrow, FadeIn, GrowArrow, Indicate, RoundedRectangle, Text, VGroup,
)

from narrated import NarratedScene

NAMES = ["브라우저", "서버", "데이터베이스"]


def boxes() -> VGroup:
    """Build the three boxes. Every scene uses the same layout and names."""
    group = VGroup()
    for name in NAMES:
        box = RoundedRectangle(width=3.2, height=1.3, corner_radius=0.2, color=BLUE)
        group.add(VGroup(box, Text(name).scale(0.55)))
    return group.arrange(RIGHT, buff=1.2)


def arrow(start, end, label: str, side) -> VGroup:
    """Build an arrow between two boxes with a label above or below it."""
    toward = RIGHT if start.get_x() < end.get_x() else LEFT
    a = Arrow(start.get_edge_center(toward), end.get_edge_center(-toward), buff=0.1)
    a.shift(side * 0.25)
    text = Text(label, color=YELLOW).scale(0.4).next_to(a, side, buff=0.1)
    return VGroup(a, text)


class S1_Parts(NarratedScene):
    def construct(self):
        self.play(FadeIn(boxes(), lag_ratio=0.4), run_time=2)


class S2_Request(NarratedScene):
    def construct(self):
        b = boxes()
        self.add(b)
        request = arrow(b[0], b[1], "요청", UP)
        query = arrow(b[1], b[2], "조회", UP)
        self.play(GrowArrow(request[0]), FadeIn(request[1]))
        self.play(Indicate(b[1]))
        self.play(GrowArrow(query[0]), FadeIn(query[1]))
        self.play(Indicate(b[2]))


class S3_Response(NarratedScene):
    def construct(self):
        b = boxes()
        self.add(b, arrow(b[0], b[1], "요청", UP), arrow(b[1], b[2], "조회", UP))
        data = arrow(b[2], b[1], "데이터", DOWN)
        response = arrow(b[1], b[0], "응답", DOWN)
        self.play(GrowArrow(data[0]), FadeIn(data[1]))
        self.play(Indicate(b[1]))
        self.play(GrowArrow(response[0]), FadeIn(response[1]))
        self.play(Indicate(b[0]))
