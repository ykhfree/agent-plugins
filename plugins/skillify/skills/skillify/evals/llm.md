# LLM eval — skillify

Each scenario describes the user input, the expected on-disk side effects, and the failure mode if the model skips parts of the procedure.

## Scenario A — explicit keyword (positive)

**User input:** "이 auth retry 로직을 skillify해줘. 다음에도 자동으로 같은 처리가 되게."

**Expected behavior:**
1. Resolver routes to skillify.
2. Step 1 classifies: `(a) verified-success-promotion`.
3. Step 2 produces a latent/deterministic split listing (deterministic items must include `validate exponential backoff config matches policy`, `assert idempotency key is sent`).
4. Step 3 runs `audit_duplicates.sh auth-retry retry backoff` and reports zero collisions.
5. Steps 5–10 produce a SKILL.md + at least one executable script + unit + integration test + evals.
6. Step 11 `validate.sh` exits 0.
7. Step 13 reproduces the original retry failure scenario; the new skill blocks it.

**Failure mode (must NOT happen):** model writes only SKILL.md, declares done, and skips deterministic code or tests. Test passes only if all 13 steps were executed in order.

## Scenario B — trivial fix (negative)

**User input:** "이 변수명 오타 좀 고쳐줘 — `usre` → `user`."

**Expected behavior:**
- Resolver does NOT route to skillify.
- Model edits the file and stops. No new skill directory is created.

**Failure mode:** model creates a `fix-typos` skill. This is a violation of "When NOT to Use" — one-off cosmetic fix with no recurrence risk.

## Scenario C — recurrence without keyword (positive)

**User input:** "또 MongoDB lag 때문에 read 결과가 비어 있어. 지난번에도 그랬는데."

**Expected behavior:**
- Recurrence (≥1 prior occurrence) detected from the user message.
- Even without the literal "skillify" keyword, model triggers skillify.
- Step 1 classifies: `(b) recurring-failure-prevention`.
- Step 2 deterministic items include: `grep changed code for read operations on reactiveMongoTemplate that follow a write in the same request`.
- Step 6 ships a script that returns non-zero when such a read is found.
- Step 13 reproduces the lag scenario and confirms the new check blocks the offending pattern.

**Failure mode:** model adds a polite reminder to AGENTS.md, CLAUDE.md, or memory and considers the task done. Instruction-file and memory entries are reminders, not deterministic gates — that is exactly the failure skillify exists to prevent.
