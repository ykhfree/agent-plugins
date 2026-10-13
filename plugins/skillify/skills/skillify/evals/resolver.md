# Resolver eval — skillify

Tests that the description-based resolver activates skillify for the right inputs and only those inputs.

## Positive triggers — MUST activate skillify

1. **Explicit Korean keyword.** "이 패턴을 skillify해줘." → activate.
2. **Synonym in Korean.** "이걸 영구화해서 다음부터 자동으로 처리되게 만들어." → activate.
3. **Recurrence signal in English.** "We've hit this same Mongo replication lag bug twice. Make sure it can't happen a third time." → activate (recurrence count ≥1).

## Negative triggers — MUST NOT activate skillify

1. **Cosmetic typo fix.** "Rename this variable from `usre` to `user`." → do not activate.
2. **Exploratory question.** "How does Armeria's circuit breaker decide when to half-open?" → do not activate (informational, not promotion).
3. **Project-specific convention proposal.** "From now on use `lateinit var` in this repo's tests." → do not activate; this belongs in `AGENTS.md` for Codex or `CLAUDE.md` for Claude Code, not a skill (covered by skillify's own "When NOT to Use").

## Verification approach

For each case, start a fresh Codex or Claude Code conversation with skillify installed and submit the prompt verbatim. Record whether the agent's first action mentions skillify (positive) or proceeds with the underlying request directly (negative). A passing resolver shows a 6/6 split across these cases.
