# Agent Plugins Marketplace

A collection of plugins for AI coding agents. One repository works with Claude Code, Codex, GitHub Copilot CLI, and any agent that supports [Agent Skills](https://agentskills.io).

🔗 **Repository**: [https://github.com/ykhfree/agent-plugins](https://github.com/ykhfree/agent-plugins)

## Available Plugins

### PR Comment Review (`pr-comment`)
Analyzes all comments on a GitHub PR and organizes unresolved items by priority.

### Skillify (`skillify`)
Turns a validated solution or a recurring failure into a permanent skill with scripts, tests, evals, and a deterministic validation gate.

### Explain Ladder (`explain-ladder`)
Re-explains a topic in a new form when the user still does not understand: STE prose, then an ASCII diagram, then a step-by-step HTML page (2D, or a 3D scene for topics with depth), then a narrated video.

### Jev Delegation (`jev-delegation`)
Hands narrow judgments to TypeSafe's Jev model through the jev CLI, and says which Jev verdicts to act on and which only advise.

### Quote Check (`quote-check`)
Checks that each quote a review or investigation report rests on appears verbatim in its file, returns the surrounding lines, and leaves the judgment of the claim to the agent.

### Orchestration Policy (`orchestration-policy`)
An opt-in policy that routes each step of a coding task to the main session, a subagent, or an advisor model, by ordered rules. Loads only when the user asks for it.

## Installation

The marketplace name is `ykhfree-plugins`. Each agent installs a plugin as `<plugin>@ykhfree-plugins`.

### Claude Code
```bash
/plugin marketplace add ykhfree/agent-plugins
/plugin install pr-comment@ykhfree-plugins
```

### Codex
```bash
codex plugin marketplace add ykhfree/agent-plugins
codex plugin add pr-comment@ykhfree-plugins
```

### GitHub Copilot CLI
```bash
copilot plugin marketplace add ykhfree/agent-plugins
copilot plugin install pr-comment@ykhfree-plugins
```

### Other agents (Cursor, Gemini CLI, and more)
Install the skills directly with the [skills CLI](https://github.com/vercel-labs/skills):
```bash
npx skills add ykhfree/agent-plugins
```

## Plugin Documentation

### PR Comment Review

#### Usage

Ask in natural language, for example "Review the comments on PR 123".
The agent picks the `pr-review` skill from its description.

In Claude Code, you can also call it directly:
```bash
/pr-comment:pr-review                                  # PR for the current branch
/pr-comment:pr-review feature/login                    # PR for a specific branch
/pr-comment:pr-review 123                              # PR number
/pr-comment:pr-review github.mycompany.com:feature/login   # GitHub Enterprise host
```

#### Features

**PR Comment Analysis**
- Review threads (suggestions/requests)
- General comments
- Automatic filtering of resolved comments

**Automatic Categorization**
- 🔧 Fix Required: Bugs, logic errors, mandatory changes
- 💬 Response Needed: Questions, explanation requests
- 💡 Suggestion: Improvement suggestions, refactoring
- 👍 Praise: Positive feedback

**Priority Sorting**
- Automatically categorized as High, Medium, or Low

#### Requirements

- GitHub CLI (`gh`) installed
- Git installed
- GitHub account authenticated (`gh auth login`)

### Skillify

#### Usage

Ask in natural language, for example "skillify this", "이걸 스킬로 만들어", or "재발 방지".
The agent picks the `skillify` skill from its description.

In Claude Code, you can also call it directly:
```bash
/skillify:skillify
```

#### What it does

The skill runs a 13-step procedure. The result is a skill directory, not a chat summary:
- `SKILL.md` with trigger phrases in `description`
- `scripts/` for every step that code can do
- `tests/unit/` and `tests/integration/`
- `evals/llm.md` and `evals/resolver.md`

Bundled scripts:

| Script | Purpose |
|---|---|
| `scripts/audit_duplicates.sh` | Finds existing skills with the same name or keywords |
| `scripts/scaffold.sh` | Creates the directory layout of a new skill |
| `scripts/validate.sh` | Runs the structure gate (frontmatter, hedging words, scripts, tests, evals, location, `HOME` pollution) |
| `scripts/run_tests.sh` | Runs every test with the current `HOME`, then with a temporary `HOME` |
| `scripts/check_recommended_skills.sh` | Lists which recommended helper skills are installed |

#### Requirements

- Bash
- Python 3 (`scripts/validate.sh` uses it to parse `SKILL.md` and the evals)
- `jq`, if you add a hook to a JSON settings file

### Explain Ladder

#### Usage

Ask a question first. If the answer is still unclear, say so, for example "아직 모르겠어", "더 쉽게 설명해", or "still not clear".
The agent picks the `explain-ladder` skill from its description and climbs one level.
To jump to a level, name it: "그림으로 보여줘", "HTML로 설명해", "3D로 보여줘", or "영상으로 설명해".

In Claude Code, you can also call it directly:
```bash
/explain-ladder:explain-ladder
```

#### Levels

| Level | Form | Rules |
|---|---|---|
| 1 | STE prose | Answer first, one point per sentence, one term per concept |
| 2 | ASCII diagram | ASCII symbols only, 72 columns or narrower, 3 to 9 boxes, checked by `scripts/check_diagram.py` |
| 3 | Single-file HTML page | One step per screen, previous/next buttons, arrow keys, step counter. A 3D variant (three.js) for topics with depth, in `skills/explain-ladder/3d.md` |
| 4 | Narrated video | Offered only; built on request with `scripts/video/build.py` (Manim, macOS `say`, ffmpeg) |

#### Requirements

- Python 3 for `scripts/check_diagram.py` (standard library only)
- Level 3, 3D variant: nothing to install. The page loads three.js 0.160.0 from cdn.jsdelivr.net
- Level 4 only: macOS, Homebrew `ffmpeg`, `cairo`, `pango`, `pkg-config`, and a Python 3.13 venv with Manim 0.22.0.
  `skills/explain-ladder/video.md` has the setup commands.

### Jev Delegation

#### Usage

The agent loads the `jev-delegation` skill before its first `jev` call, or when a judgment spans many items:
a large log to search, many search hits to rank, fetched pages to screen, screenshots to rank or click, or a photo to check for named objects.
A short pointer in your agent instructions (for example `~/.claude/CLAUDE.md`) makes the agent load it first.

In Claude Code, you can also call it directly:
```bash
/jev-delegation:jev-delegation
```

#### What it covers

| Part | Content |
|---|---|
| Commands | `find`, `rank`, `screen`, `search`, `which`, `locate`, `detect` |
| Images | Only fixture or dev screens, and public-domain or fixture photos with no people |
| Never delegate | Generative work, arithmetic, a few items already in context, real secrets |
| Jev decides | Verdicts the agent acts on without re-reading the item |
| Jev advises | Verdicts the agent checks against the source |
| `scripts/scan_secrets.py` | Scans files before they go to Jev, and prints `path:line: pattern` without the value |
| `scripts/verdict.py` | Reads one `jev` result and says whether it decides (exit 0) or only advises (exit 1) |

#### Requirements

- The `jev` CLI on `PATH`. It is not published, so this plugin is useful only where `jev` is installed.
- `TYPESAFE_API_KEY` in the environment. Every `jev` call is a billed TypeSafe request.
- Python 3.10 or later for the scripts.

### Quote Check

#### Usage

The agent loads the `quote-check` skill before it sends a code review, investigation, or root-cause report that cites code or docs it did not change.
You can also ask for it: "인용 확인해줘", "근거 확인", or "quote check".

In Claude Code, you can also call it directly:
```bash
/quote-check:quote-check
```

#### How it works

1. The agent writes each key claim as `{"claim", "file", "quote"}` in a JSON list.
2. `scripts/quote_check.py` looks for each quote in its file. It ignores whitespace differences and curly quotes.
3. The script gives each claim one verdict: `found` (with the line range and 15 lines on each side), `fabricated`, or `file_missing`.
4. The agent reads each `found` section and decides if it supports, contradicts, or does not settle the claim.
5. The agent reports only supported claims, and labels the claims it could not settle as unverified.

The script does not judge claims. In an eval on the same sections, Claude judged 39 of 39 correctly and a small model judge 34 of 39.

#### Requirements

- Python 3.10 or later. The script uses only the standard library.

### Orchestration Policy

#### Usage

The skill loads only when you ask for it. Its description tells the agent not to load it on its own.
Ask in natural language, for example "오케스트레이션 정책 적용해" or "apply the orchestration policy".
After it loads, the agent applies it to every task in the session until you say to stop.

In Claude Code, you can also call it directly:
```bash
/orchestration-policy:orchestration-policy
```

#### What it covers

| Part | Content |
|---|---|
| Roles | Main session, `deep-reasoner`, `feature-developer`, `fast-worker`, `fast-explorer`, `Explore`, critic, advisor |
| Step facts | Five rules, evaluated top to bottom; the first match wins. If none matches, the main session does the step |
| Search facts | Who searches, by how hard the search is |
| Advisor events | When to consult, when not to, and at most 3 consults per task |
| `scripts/route.py` | Applies the rules to the facts the agent judged, and stops a 4th advisor consult |

#### Requirements

- Subagents with the role names above. The plugin does not include them.
  If an agent is not installed, the main session does that step itself.
- An advisor model, such as Claude Code's advisor tool. Without one, the agent asks the user at each consult point.
- Python 3.10 or later for the script.

## Contributing

To add a plugin, follow the portability rules in [AGENTS.md](AGENTS.md).

## License

MIT
