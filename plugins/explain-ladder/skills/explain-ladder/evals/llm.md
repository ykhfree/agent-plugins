# LLM eval — explain-ladder

Each scenario gives the user input, the expected behavior, and the failure mode if the model skips the procedure.

## Scenario A — still unclear after level 1 (climb one level)

**Context:** The model explained how a web request flows (브라우저, 서버, 데이터베이스) in level 1 prose.

**User input:** "아직 모르겠어."

**Expected behavior:**
1. The model finds the current level (1) and the target level (2).
2. The model draws an ASCII diagram with 3 boxes named 브라우저, 서버, 데이터베이스, the same names as the prose.
3. The model runs `scripts/check_diagram.py` on the diagram and sends it only after exit 0.
4. A numbered list follows the diagram, one item per arrow, in flow order.
5. The last line offers level 3 (HTML page).

**Failure mode (must NOT happen):** the model rewrites the same prose with other words, or draws the boxes with box-drawing characters (`┌─┐`) that the checker rejects.

## Scenario B — the user names a level (jump)

**Context:** The model explained database indexing in level 1 prose.

**User input:** "HTML로 설명해."

**Expected behavior:**
1. The model goes to level 3 directly and does not draw a level 2 diagram first.
2. The page shows one step per screen, with "이전" and "다음" buttons, left and right arrow keys, and a step counter.
3. The last step shows the whole picture at once.
4. The model publishes the page with the agent's HTML tool, or writes the file and gives its path.
5. The last line offers level 4 (video) in one sentence and does not build it.

**Failure mode (must NOT happen):** the model climbs one level only (to level 2) and ignores the named level, or builds the video without a request.

## Scenario C — content disagreement (stay at the current level)

**Context:** The model drew a level 2 diagram of an OAuth flow.

**User input:** "그 화살표 방향이 틀렸어. 토큰은 서버가 브라우저로 보내."

**Expected behavior:**
1. The model does not climb to level 3.
2. The model fixes the arrow direction in the level 2 diagram, runs `scripts/check_diagram.py` again, and sends the corrected diagram.

**Failure mode (must NOT happen):** the model treats the message as "still unclear" and builds an HTML page with the same wrong arrow.

## Scenario D — the user asks for 3D (level 3, 3D variant)

**Context:** The model explained how Postgres writes an `UPDATE` (백엔드 프로세스, shared buffers, WAL buffers, WAL 파일, 데이터 파일) in level 1 prose.

**User input:** "3D로 보여줘."

**Expected behavior:**
1. The model goes to level 3 with the 3D variant and reads `3d.md` before it writes the page.
2. The scene uses the same part names as the prose, and it places memory and disk on separate layers.
3. The page keeps the level 3 controls: "이전" and "다음" buttons, left and right arrow keys, and a step counter. The last step is a summary.
4. The page loads three.js through an import map with an exact version, such as `three@0.160.0`.
5. The model checks the page once (screenshots, phone width, animation run), publishes it, and names what it could not check.

**Failure mode (must NOT happen):** the model builds a free-rotating 3D model with no steps and no counter, loads three.js without a pinned version, or builds a 2D page and ignores the request.

## Scenario E — level 3 for a flow without depth (stay in 2D)

**Context:** The model drew a level 2 diagram of a login sequence with 3 boxes: 브라우저, 서버, 데이터베이스.

**User input:** "아직 모르겠어."

**Expected behavior:**
1. The model climbs to level 3 and builds a 2D page.
2. The model does not choose the 3D variant, because the sequence has no depth and the user did not ask for 3D.

**Failure mode (must NOT happen):** the model builds a 3D scene because the variant exists. Then parts hide each other, and the user must rotate the view to read a simple sequence.
