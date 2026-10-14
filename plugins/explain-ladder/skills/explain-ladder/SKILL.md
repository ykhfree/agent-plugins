---
name: explain-ladder
description: Use when the user says an explanation is still unclear and wants it explained another way — "아직 모르겠어", "이해가 안 돼", "더 쉽게 설명해", "그림으로 보여줘", "다이어그램으로", "HTML로 설명해", "explain in HTML", "영상으로 설명해", "still not clear", "explain it differently". Climbs one level of the explanation ladder (STE prose → ASCII diagram → single-file HTML → video) and defines the output rules for each level.
---

# explain-ladder

## Overview
Explanations climb a ladder of four levels. Start at level 1. Climb one level only when the user
still does not understand. Each level has its own output rules, defined below.

```
1 STE prose --> 2 ASCII diagram --> 3 HTML page --> 4 video
       (climb one level each time the user is still unclear)
```

Trigger class: (a) verified-success-promotion. The ladder was used in real sessions, and level 4
built a narrated Korean demo video from a three-step level 3 page.

Each sub-step is either model judgment (LATENT) or code (DETERMINISTIC):

| Sub-step | Kind | Done by |
|---|---|---|
| Find the current level and the target level | LATENT | Procedure steps 1–2 |
| Find the point of confusion | LATENT | Procedure step 3 |
| Write the explanation at the target level | LATENT | Level rules |
| Check a level 2 diagram: allowed characters, width, box count | DETERMINISTIC | `scripts/check_diagram.py` |
| Check `script.json`, make the narration, pad each scene to it, join the video | DETERMINISTIC | `scripts/video/build.py` |
| Check a level 4 video frame for overlapping or missing text | LATENT | `video.md` step 6 |

## When to Use
- The user says the last explanation is unclear, or asks for a simpler or different form.
- The user names a level directly: "그림으로", "HTML로 설명해", "영상으로".

## When NOT to Use
- The first explanation of a topic. Write level 1 prose (the level 1 rules below) without climbing.
- The user asks a new question on a different topic. Start again at level 1.
- The user disagrees with the content, not the form. Fix the content at the current level.

## Mandatory Procedure
1. Find the current level: look at the form of your last explanation of this topic.
2. Find the target level:
   - If the user names a level, use that level.
   - If not, use the current level + 1.
   - If the target is level 2 and the topic has fewer than 3 parts, a diagram adds little.
     Rewrite level 1 with one concrete example (real values, real names) instead.
     If the user is still stuck after that, go to level 3.
3. Find the point of confusion. If the user said which part is unclear, explain only that part.
   If not, explain the whole topic again.
4. Produce the output with the rules of the target level below.
   Do not paste the previous explanation again. Change the form, not only the words.
5. Keep the terms. Every name in the new form must match the name in the earlier levels.
6. End with one line that names the next level, for example
   "아직 헷갈리면 HTML 페이지로 단계별로 보여드릴게요."
   Do not add this line at level 4.

## Level rules
Paths in this section are relative to this skill's directory.

### Level 1 — STE prose
These rules apply ASD-STE100 (Simplified Technical English) clarity principles.
If the user's own instructions define writing rules, follow those rules instead.
- Put the answer first, in one to three sentences. Put details after it.
- Put one main point or one action in each sentence.
- Use active voice and name the actor.
- Use one term for one concept. Do not switch between synonyms.
- Put the condition before the instruction ("If X, do Y").
- Write sequential steps as a numbered list, one action per step.
- Replace vague words ("appropriately", "some", "various") with the specific name or value.
  If the value is unknown, say so. Do not invent a value.
- Keep necessary nuance, evidence, and exact quotations.
- English: keep instructions to 20 words or fewer and descriptions to 25 words or fewer.
- Korean: do not count words. Shorten a sentence by splitting its ideas.

### Level 2 — ASCII diagram
Use for flows and structures with 3 or more parts.
- Put the diagram in a fenced code block.
- Draw with ASCII symbols only: `+ - | v ^ < >`. Box-drawing characters and Unicode arrows break
  alignment in some terminals. Names and labels can use letters of any language.
- Keep every line 72 columns or narrower. A wide character (Hangul, CJK) fills 2 columns.
- Use 3 to 9 boxes. If more are needed, draw the top level only and offer to zoom into one box.
- Draw each box with `+---+` edges and `|` sides. Put a `|` directly under each top corner.
- Write one name in each box. Use the same name as the prose.
- Label each arrow with what moves along it (data, call, event), unless the label is obvious.
- Flow goes top to bottom or left to right. Do not cross arrows.
- After the diagram, write a numbered list: one item per arrow, in flow order.
- Before you send the diagram, check it. Pass the diagram text on stdin:
  ```bash
  python3 scripts/check_diagram.py <<'DIAGRAM'
  <the diagram>
  DIAGRAM
  ```
  If it exits 1, fix every line it lists, then run it again. Send the diagram only after exit 0.

### Level 3 — single-file HTML page
- Build one self-contained HTML file.
  - If the agent has a tool that publishes HTML pages, publish the page with it and follow that
    tool's design rules. In Claude Code, this is the `Artifact` tool with the `artifact-design` skill.
  - If not, write the file and give the user its path.
- If the topic is a system architecture, sequence, data flow, or state machine, and the `archify`
  skill is installed, use it for the diagram part.
- Show one step per screen. Give "이전" and "다음" buttons, left and right arrow keys, and a
  step counter ("3 / 7").
- In each step, write one or two sentences and show one visual. Highlight only the part that changed
  in this step.
- Use the level 2 diagram as the backbone if one exists: same boxes, same names, same order.
- Make the last step a summary that shows the whole picture at once.

### Level 4 — explainer video
- If the user is still stuck after level 3, offer the video in one sentence. Build it only if the user asks.
- Level 4 runs on macOS only: it uses the macOS `say` command for the voice.
  If the machine is not macOS, tell the user, and stay at level 3.
- Read `video.md` in this skill directory and follow its procedure. It uses Manim, `say`, and ffmpeg.
- Build the scenes from the level 3 steps: same steps, same names, same order.

## Relationship to other skills
- `archify` draws polished architecture diagrams as HTML. This skill calls it at level 3; it does not
  replace it. Both skills match the words "diagram" and "HTML". `archify` makes a diagram that the
  user asks for. This skill changes the form of an explanation that the user did not understand.
- `artifact-design` and `artifact-diagramming` hold the Claude Code page and SVG rules for level 3.
