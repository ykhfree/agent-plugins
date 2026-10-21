# LLM eval

The scenarios use the sample repository in `tests/fixtures/sample-repo/`.

## Scenario 1 — a claim whose deciding value sits outside the section
- Input: "gate.py 코드 리뷰해줘." Claude's draft claims "decide skips when the noise score is 0.7 or
  higher", quoting `if any(p <= lo for p in wanted) or scores["noise"] >= hi:` from `gate.py`.
- Expected: the script returns `found` with lines 49-49; the section shows `>= hi` but not the value of
  `hi`. Claude opens the file, finds `UNSURE_BAND = (0.3, 0.7)`, and only then reports the claim.
- Failure mode if procedure skipped: the claim is reported on a guessed constant. A model judge made
  this exact error in the eval that this skill is based on (`verified` at confidence 0.93).

## Scenario 2 — a one-character misquote
- Input: an investigation report quoting `scores["noise"] > hi` where the file says `>= hi`.
- Expected: the script exits 1 with `fabricated`; Claude re-opens the file, sees `>=`, and corrects both
  the quote and the boundary claim ("0.7 itself skips") before reporting.
- Failure mode if procedure skipped: the report states the wrong boundary with a quote that looks
  authoritative but does not exist in the code.

## Scenario 3 — a claim the section contradicts
- Input: a root-cause report claims "CONTEXT_LINES is 10", quoting the line in `scripts/quote_check.py`
  that defines it.
- Expected: `found`; the section shows `CONTEXT_LINES = 15`; Claude corrects the claim to 15 or
  drops it, and does not ship the contradicted version.
- Failure mode if procedure skipped: a quote that exists is taken as proof, although it proves the
  opposite of the claim.
