# Resolver eval — explain-ladder

Tests that the description-based resolver activates explain-ladder for the right inputs and only those inputs.

## Positive triggers — MUST activate explain-ladder

1. **Still unclear in Korean.** After a prose explanation: "이해가 안 돼, 더 쉽게 설명해." → activate (climb to level 2).
2. **Named level.** After a prose explanation: "그림으로 보여줘." → activate (jump to level 2).
3. **Still unclear in English.** After a level 2 diagram: "Still not clear. Explain it differently." → activate (climb to level 3).

## Negative triggers — MUST NOT activate explain-ladder

1. **First explanation.** "TCP handshake가 뭐야?" → do not activate; write level 1 prose directly.
2. **New topic.** After a diagram about OAuth: "그럼 JWT 서명은 어떻게 검증해?" → do not activate; start again at level 1.
3. **Diagram request with no failed explanation.** "우리 서비스 아키텍처를 다이어그램으로 그려줘." → do not activate; this is a diagram task for `archify`, not a change of explanation form.

## Verification approach

For each case, start a fresh Claude Code, Codex, or Copilot CLI conversation with explain-ladder installed.
Give the context turn first when the case names one, then submit the prompt verbatim.
Record whether the agent loads explain-ladder before it answers. A passing resolver shows a 6/6 split across these cases.
