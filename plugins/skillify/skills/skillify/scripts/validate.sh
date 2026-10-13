#!/usr/bin/env bash
# Validate that a skill directory satisfies the skillify gate.
# Usage: validate.sh <skill-dir>
# Exit codes: 0 = pass, 1 = structural failure, 2 = bad invocation
set -euo pipefail

skill_dir="${1:?usage: validate.sh <skill-dir>}"
[[ -d "$skill_dir" ]] || { echo "not a directory: $skill_dir" >&2; exit 2; }

fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

skill_md="$skill_dir/SKILL.md"
[[ -f "$skill_md" ]] || fail "missing SKILL.md"

python3 - "$skill_md" <<'PY' || fail "frontmatter invalid"
import sys, re, pathlib
p = pathlib.Path(sys.argv[1]).read_text()
m = re.match(r"^---\n(.*?)\n---\n", p, re.S)
if not m:
    sys.exit(1)
fm = {}
for line in m.group(1).splitlines():
    if ": " in line:
        k, v = line.split(": ", 1)
        fm[k.strip()] = v.strip()
name = fm.get("name", "")
desc = fm.get("description", "")
if not re.fullmatch(r"[a-z0-9-]+", name):
    sys.exit(1)
if not desc.lower().startswith("use when"):
    sys.exit(1)
if len(desc) > 1024:
    sys.exit(1)
PY
ok "frontmatter"

dir_name="$(basename "$skill_dir")"
grep -qE "^name: ${dir_name}\$" "$skill_md" || fail "name does not match dir ($dir_name)"
ok "name match"

# Forbidden hedging words must NOT appear in the narrative body of SKILL.md.
# We strip frontmatter, fenced code blocks, inline code spans, and the
# rationalization-table block before checking — that way a SKILL.md can
# legitimately document hedging words as bad examples (inside backticks or
# inside the rationalization table) without tripping the check on itself.
python3 - "$skill_md" <<'PY' || fail "forbidden hedging language in SKILL.md body"
import sys, re, pathlib
text = pathlib.Path(sys.argv[1]).read_text()
text = re.sub(r"^---\n.*?\n---\n", "", text, count=1, flags=re.S)
text = re.sub(r"```.*?```", "", text, flags=re.S)
text = re.sub(r"`[^`]*`", "", text)
text = re.sub(r"## Rationalization table.*?(?=\n## |\Z)", "", text, flags=re.S)
for w in ["가능하면", "보통", "웬만하면", "possibly", "usually", "try to"]:
    if w in text:
        print(f"hedging hit: {w}", file=sys.stderr)
        sys.exit(1)
PY
ok "no hedging"

[[ -d "$skill_dir/scripts" && -n "$(ls -A "$skill_dir/scripts" 2>/dev/null)" ]] \
  || fail "scripts/ missing or empty"
for f in "$skill_dir"/scripts/*; do
  [[ -x "$f" ]] || fail "not executable: $f"
done
ok "scripts"

[[ -d "$skill_dir/tests/unit"        && -n "$(ls -A "$skill_dir/tests/unit" 2>/dev/null)" ]] \
  || fail "tests/unit empty"
[[ -d "$skill_dir/tests/integration" && -n "$(ls -A "$skill_dir/tests/integration" 2>/dev/null)" ]] \
  || fail "tests/integration empty"
ok "tests"

[[ -s "$skill_dir/evals/llm.md"      ]] || fail "evals/llm.md missing or empty"
[[ -s "$skill_dir/evals/resolver.md" ]] || fail "evals/resolver.md missing or empty"

# Structural eval check: enforce SKILL.md Step 9's "three scenarios" / positive +
# negative routing requirement. Without this, scaffold-time TODO placeholders
# slip past the gate unchanged.
python3 - "$skill_dir/evals/llm.md" "$skill_dir/evals/resolver.md" <<'PY' || fail "evals do not satisfy structural requirements (see stderr)"
import sys, re, pathlib

llm_path, resolver_path = sys.argv[1], sys.argv[2]
llm_text      = pathlib.Path(llm_path).read_text()
resolver_text = pathlib.Path(resolver_path).read_text()

# (1) Reject leftover scaffold placeholders. The literal token "TODO" anywhere
# in either file means the author shipped without filling the eval out.
for path, text in [(llm_path, llm_text), (resolver_path, resolver_text)]:
    if "TODO" in text:
        print(f"unfilled TODO placeholder remains in {path}", file=sys.stderr)
        sys.exit(1)

def count_scenarios(text):
    # A scenario is either a header containing "Scenario"/"Case" (any case) or
    # a top-level enumerated list item. Take the maximum of the two counts so
    # authors can use whichever convention fits the eval.
    headers = len(re.findall(r"(?im)^#{2,4} .*\b(scenario|case)\b", text))
    enums   = len(re.findall(r"(?m)^[0-9]+\. ", text))
    return max(headers, enums)

if count_scenarios(llm_text) < 3:
    print(f"evals/llm.md needs >=3 scenarios (markdown headers containing 'Scenario'/'Case', or numbered list items)", file=sys.stderr)
    sys.exit(1)

# (2) resolver.md: must have a Positive section and a Negative section, each
# with >=3 enumerated cases. Partition the file by markdown headers, then count
# enumerated/bulleted items inside the matching sections.
def section_items(text, section_word):
    # Find header lines containing the keyword (case-insensitive). For each
    # match, extract content up to the next header at the same or shallower
    # depth.
    pattern = re.compile(r"(?im)^(#{1,6}) +.*\b" + section_word + r"\b.*$")
    matches = list(pattern.finditer(text))
    if not matches:
        return None
    total = 0
    for m in matches:
        depth = len(m.group(1))
        start = m.end()
        # Next sibling-or-shallower header ends this section.
        next_header = re.compile(r"(?m)^#{1," + str(depth) + r"} +", )
        rest = text[start:]
        end_match = next_header.search(rest)
        end = start + (end_match.start() if end_match else len(rest))
        body = text[start:end]
        total += len(re.findall(r"(?m)^\s*(?:[-*]|[0-9]+\.) +\S", body))
    return total

pos = section_items(resolver_text, "positive")
neg = section_items(resolver_text, "negative")
if pos is None:
    print("evals/resolver.md missing a 'Positive' section header", file=sys.stderr); sys.exit(1)
if neg is None:
    print("evals/resolver.md missing a 'Negative' section header", file=sys.stderr); sys.exit(1)
if pos < 3:
    print(f"evals/resolver.md Positive section has {pos} enumerated items; need >=3", file=sys.stderr); sys.exit(1)
if neg < 3:
    print(f"evals/resolver.md Negative section has {neg} enumerated items; need >=3", file=sys.stderr); sys.exit(1)
PY
ok "evals"

abs="$(cd "$skill_dir" && pwd)"
case "$abs" in
  "$HOME/.claude/skills/"*)             ok "location" ;;
  "$HOME/.agents/skills/"*)             ok "location" ;;
  "$HOME/.codex/skills/"*)              ok "location" ;;
  */.claude/skills/*)                    ok "location" ;;
  */.agents/skills/*)                    ok "location" ;;
  */.codex/skills/*)                     ok "location" ;;
  */.claude/plugins/cache/*/skills/*)    ok "location" ;;
  */.codex/plugins/cache/*/skills/*)     ok "location" ;;
  *) fail "skill not under a recognized runtime skill or plugin cache tree (got: $abs)" ;;
esac

script_dir="$(cd "$(dirname "$0")" && pwd)"

# Gate 10: tests must not write to real runtime skill directories. Use mktemp
# plus HOME injection instead. The exec is on its own subshell so a
# stderr-bearing failure surfaces directly.
"$script_dir/check_test_home_pollution.sh" "$skill_dir" \
  || fail "tests pollute real runtime skill directories (use mktemp + HOME= injection); see stderr for offending lines"
ok "test-home-isolation"

# Informational: warn when SKILL.md references a recommended sub-skill that is
# not actually installed in the runtime. Never changes the exit code — the
# hard policy is the 10 gates above; recommended skills are advisory only.
checker="$script_dir/check_recommended_skills.sh"
if [[ -x "$checker" ]]; then
  refs="$(grep -oE '(superpowers|claude-plugins-official):[a-z0-9-]+|\$skill-creator' "$skill_md" | sed 's/^\$//' | sort -u || true)"
  if [[ -n "$refs" ]]; then
    status="$("$checker" 2>/dev/null || true)"
    while IFS= read -r ref; do
      [[ -z "$ref" ]] && continue
      if printf '%s\n' "$status" | grep -qE "^${ref} absent$"; then
        echo "WARN: SKILL.md references ${ref} but the recommended skill is not installed; ensure the inline fallback (D1/D2/D3) is followed." >&2
      fi
    done <<< "$refs"
  fi
fi

echo "PASS: $skill_dir"
