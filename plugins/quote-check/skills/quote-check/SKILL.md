---
name: quote-check
description: Use when about to report a code review, investigation, or root-cause analysis whose claims cite specific lines of code or docs you did not change in this session, or when the user asks to verify quotes/citations in such a report ("인용 확인", "근거 확인", "quote check").
---

# quote-check

## Overview
Trigger class: (a) verified-success-promotion. Before a report goes out, every key claim that rests on a
quote is checked in two steps: a script confirms the quote exists verbatim in its file and returns the
surrounding lines (deterministic), then you judge the claim against those lines (latent).

The judgment stays with you on purpose. An eval measured TypeSafe's Jev model doing it:
given the same ±15-line section, Claude scored 39/39 and Jev 34/39, and every Jev error was `verified` on a
fact the section did not show (once at confidence 0.93). The model step was removed; this skill keeps the
part that needs no model.

## When to Use
- A code review, investigation, or root-cause report is about to be sent, and it claims what code or docs
  you did not change say or do.
- The user asks you to verify the quotes or citations in such a report.

## When NOT to Use
- Claims about your own edits in this session that tests already verified.
- Claims that do not rest on one specific quote: "no X exists", "X is never called", whole-codebase or
  performance claims. Verify those with search or by running code instead.
- Plain answers and explanations that cite nothing.

## Mandatory Procedure
1. LATENT — pick the key claims: the ones the report's conclusion depends on, each resting on one quote.
2. LATENT — write them as a JSON list of `{"claim", "file", "quote"}`. Copy each quote verbatim from the
   file text: no line-number prefixes (`42→`, `L42|`), no ellipsis, no paraphrase. A quote may span
   wrapped lines; whitespace and curly quotes are normalized.
3. DETERMINISTIC — run `python3 scripts/quote_check.py claims.json` (or pipe the JSON on stdin).
   The script path is relative to this skill's directory.
   Relative `file` paths in the JSON resolve against the current directory.
   Exit 0 = every quote found; 1 = at least one `fabricated` or `file_missing`; 2 = bad input (fix the
   JSON shape and rerun).
4. LATENT — handle each result:
   - `found`: read its `section` (the quoted `lines` plus 15 lines each side). Decide: supports,
     contradicts, or does not settle the claim. When the claim depends on anything the section does not
     show (a constant defined elsewhere, a caller in another file), open the file and read it; never infer
     the missing value.
   - `fabricated`: re-open the file first. It is most often your own misquote: fix the quote and rerun.
     When the text truly differs, the claim is wrong: correct it or drop it.
   - `file_missing`: fix the path and rerun, or drop the claim.
5. Report only claims you judged supported. Correct or remove contradicted ones; label claims you could
   not settle as unverified.

## Relationship to other skills
- Use this skill, not the `jev claims` command of the `jev` CLI: that command keeps the model-judged
  version, which the eval above found less accurate than your own judgment on the same section.
- The `typesafe-ai` skill has a model-based citation_check cookbook; this skill is the model-free
  alternative the eval favoured, so the two do not overlap in use.
