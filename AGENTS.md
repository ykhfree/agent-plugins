# AGENTS.md

This file gives guidance to AI coding agents (Claude Code, Codex, GitHub Copilot, and others) that work in this repository.
`CLAUDE.md` imports this file, so keep all guidance here.

## Project Overview

This repository is a plugin marketplace that several AI coding agents can install from.
Each plugin is versioned on its own and lives in its own directory under `plugins/`.

**Repository**: https://github.com/ykhfree/agent-plugins

Current plugins:
- **pr-comment**: Analyzes GitHub PR comments and categorizes them by priority
- **skillify**: Turns a validated solution or a recurring failure into a permanent skill with scripts, tests, and evals
- **explain-ladder**: Re-explains a topic in a new form (prose, ASCII diagram, 2D or 3D HTML page, video) when the user still does not understand
- **jev-delegation**: Says when to hand a narrow judgment to TypeSafe's Jev through the `jev` CLI, and which verdicts to trust
- **quote-check**: Checks that the quotes a review or investigation report cites appear verbatim in their files, before the report goes out
- **orchestration-policy**: An opt-in policy that routes each step of a task to the main session, a subagent, or an advisor model

## Compatibility

One layout serves every supported agent. Tested on Claude Code 2.1.296, Codex CLI 0.142.3, and Copilot CLI 1.0.10.
The `.codex-plugin/plugin.json` files and `.agents/plugins/marketplace.json` were added on 2026-10-14 and tested on Codex CLI 0.142.3 only.

| File | Claude Code | Codex | Copilot CLI |
|------|-------------|-------|-------------|
| `.claude-plugin/marketplace.json` | Native | Read only if `.agents/plugins/marketplace.json` is missing | Read (fallback location) |
| `.agents/plugins/marketplace.json` | Not read | Native: read first | Not tested |
| `plugins/<name>/.claude-plugin/plugin.json` | Native | Read only if `.codex-plugin/plugin.json` is missing | Read (legacy manifest location) |
| `plugins/<name>/.codex-plugin/plugin.json` | Not read | Native: read first | Not tested |
| `plugins/<name>/skills/<skill>/SKILL.md` | Native | Native | Native |

Agents without a plugin system can install the skills directly with `npx skills add ykhfree/agent-plugins`.
The skills follow the open [Agent Skills](https://agentskills.io/specification) format.

Do not add a root `plugin.json` (Agent Plugins format). Codex 0.142.3 ignores it and builds its manifest from the marketplace entry, so it only adds a second copy of the metadata to keep in sync.

## Structure

```
/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace for Claude Code and Copilot CLI
├── .agents/
│   └── plugins/
│       └── marketplace.json      # Marketplace for Codex (same plugins, adds policy and category)
├── plugins/
│   ├── pr-comment/
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json       # Plugin metadata for Claude Code and Copilot CLI
│   │   ├── .codex-plugin/
│   │   │   └── plugin.json       # Plugin metadata for Codex (adds skills and interface)
│   │   └── skills/
│   │       └── pr-review/
│   │           └── SKILL.md      # Skill instructions
│   ├── skillify/
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── .codex-plugin/
│   │   │   └── plugin.json
│   │   └── skills/
│   │       └── skillify/
│   │           ├── SKILL.md
│   │           ├── scripts/      # Bash scripts that the skill runs
│   │           ├── tests/        # Tests of skillify itself
│   │           └── evals/
│   ├── explain-ladder/
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── .codex-plugin/
│   │   │   └── plugin.json
│   │   └── skills/
│   │       └── explain-ladder/
│   │           ├── SKILL.md
│   │           ├── 3d.md         # Level 3 3D variant rules
│   │           ├── video.md      # Level 4 procedure
│   │           ├── examples/     # 3D reference page
│   │           ├── scripts/      # check_diagram.py, video/ (build.py + pytest suite)
│   │           ├── tests/        # Shell tests that run_tests.sh finds
│   │           └── evals/
│   ├── jev-delegation/
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── .codex-plugin/
│   │   │   └── plugin.json
│   │   └── skills/
│   │       └── jev-delegation/
│   │           └── SKILL.md      # Commands, image rules, and which verdicts to trust
│   ├── quote-check/
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── .codex-plugin/
│   │   │   └── plugin.json
│   │   └── skills/
│   │       └── quote-check/
│   │           ├── SKILL.md
│   │           ├── scripts/      # quote_check.py (standard library only)
│   │           ├── tests/        # Shell tests that run_tests.sh finds, and a sample repository
│   │           └── evals/
│   └── orchestration-policy/
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── .codex-plugin/
│       │   └── plugin.json
│       └── skills/
│           └── orchestration-policy/
│               └── SKILL.md      # Roles, routing rules, search steps, and advisor rules
├── AGENTS.md
├── CLAUDE.md                     # Imports AGENTS.md
└── README.md
```

## Portability Rules

Every plugin must work in every supported agent. Follow these rules:

1. Put functionality in `skills/<skill-name>/SKILL.md`. Do not use `commands/`: Codex does not load it, and Copilot loads it only when the manifest names it.
2. Give each `SKILL.md` frontmatter with exactly `name` and `description`.
   - `name` must equal the skill directory name (lowercase letters, digits, and hyphens).
   - `description` says what the skill does and when to use it. Agents choose a skill from this text.
3. Do not use features that only one agent has:
   - `$ARGUMENTS` or `argument-hint`: describe the input the user can give in prose instead.
   - `${CLAUDE_SKILL_DIR}` or `${CLAUDE_PLUGIN_ROOT}`: refer to bundled files by their path relative to the skill directory, such as `scripts/run.py`.
   - Tool names such as `AskUserQuestion`: write "ask the user and wait for the answer".
4. Keep scripts that a skill runs inside the skill directory (`skills/<skill>/scripts/`).

## Creating a New Plugin

1. Create the directories:
   ```bash
   mkdir -p plugins/{plugin-name}/.claude-plugin
   mkdir -p plugins/{plugin-name}/.codex-plugin
   mkdir -p plugins/{plugin-name}/skills/{skill-name}
   ```
2. Create `plugins/{plugin-name}/.claude-plugin/plugin.json`:
   ```json
   {
     "name": "plugin-name",
     "version": "1.0.0",
     "description": "Plugin description",
     "author": {"name": "Author Name"}
   }
   ```
3. Create `plugins/{plugin-name}/.codex-plugin/plugin.json`.
   Copy every field of the Claude manifest, then add `skills` and `interface`:
   ```json
   {
     "name": "plugin-name",
     "version": "1.0.0",
     "description": "Plugin description",
     "author": {"name": "Author Name"},
     "skills": "./skills/",
     "interface": {
       "displayName": "Plugin Name",
       "shortDescription": "Subtitle for compact views",
       "longDescription": "Plugin description",
       "developerName": "Author Name",
       "category": "Developer Tools",
       "capabilities": ["Interactive", "Write"],
       "websiteURL": "https://github.com/ykhfree/agent-plugins",
       "defaultPrompt": ["A starter prompt of about 50 characters"]
     }
   }
   ```
   - `defaultPrompt`: at most 3 strings, each 128 characters or shorter. Codex ignores extra entries and cuts longer ones.
   - `category` and `capabilities`: use values that OpenAI plugins use. Categories include `Developer Tools`,
     `Productivity`, and `Education & Research`. Capabilities are `Interactive`, `Read`, and `Write`.
   - Add `privacyPolicyURL`, `termsOfServiceURL`, `logo`, `composerIcon`, or `screenshots` only when the file or page exists.
     Put images under `./assets/`.
   - Spec: [plugin-json-spec.md](https://github.com/openai/plugins/blob/main/.agents/skills/plugin-creator/references/plugin-json-spec.md)
     and [Build plugins](https://developers.openai.com/codex/plugins/build/).
4. Write `plugins/{plugin-name}/skills/{skill-name}/SKILL.md` by the portability rules above.
5. Register the plugin in `.claude-plugin/marketplace.json`:
   ```json
   {
     "name": "plugin-name",
     "source": "./plugins/{plugin-name}",
     "description": "Plugin description",
     "version": "1.0.0",
     "author": {"name": "Author Name"}
   }
   ```
6. Register the plugin in `.agents/plugins/marketplace.json` for Codex. Use the same order as step 5:
   ```json
   {
     "name": "plugin-name",
     "source": {"source": "local", "path": "./plugins/{plugin-name}"},
     "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"},
     "category": "Developer Tools"
   }
   ```
   `category` must equal `interface.category` in `.codex-plugin/plugin.json`.
   If this file exists, Codex ignores `.claude-plugin/marketplace.json`, so a plugin missing here cannot be installed in Codex.
7. Add the plugin to the "Available Plugins" section of `README.md`.

## Naming

Only Claude Code puts the plugin name in front of a skill name (`/plugin-name:skill-name`).
Copilot CLI and the skills CLI show the bare skill name, so a generic name such as `review` can clash with another skill.
Give each skill a name that is clear without the plugin name, and keep it short.
Example: plugin `pr-comment` with skill `pr-review` runs as `/pr-comment:pr-review` in Claude Code and appears as `pr-review` elsewhere.

## Metadata Synchronization

When you change a plugin, keep these in sync:
1. `plugins/{plugin-name}/.claude-plugin/plugin.json`: `version`, `description`
2. `plugins/{plugin-name}/.codex-plugin/plugin.json`: the same `version` and `description`, and `interface.longDescription`
3. `.claude-plugin/marketplace.json`: the matching entry. Its `version` must equal the `plugin.json` version.
   Claude Code reads the version from `.claude-plugin/plugin.json`, Codex from `.codex-plugin/plugin.json`,
   and Copilot CLI from the marketplace entry.
4. `.agents/plugins/marketplace.json`: the same plugins in the same order, with `category` equal to the Codex manifest.
   This file has no `version` field.
5. `README.md`: the "Available Plugins" section and the plugin documentation

Raise the version on every change that users should receive. Claude Code and Codex keep an installed plugin at its version until the version changes.

## Verification

Run these checks before you push:

```bash
# Claude Code: validate the marketplace and each plugin
claude plugin validate .
claude plugin validate ./plugins/<plugin-name>

# All agents: the two marketplaces and the plugin manifests must agree
python3 - <<'PY'
import json
market = {p["name"]: p for p in json.load(open(".claude-plugin/marketplace.json"))["plugins"]}
codex_market = {p["name"]: p for p in json.load(open(".agents/plugins/marketplace.json"))["plugins"]}
assert list(market) == list(codex_market), ("marketplace plugin lists differ", list(market), list(codex_market))
for name, entry in market.items():
    claude = json.load(open(f"plugins/{name}/.claude-plugin/plugin.json"))
    codex = json.load(open(f"plugins/{name}/.codex-plugin/plugin.json"))
    for key in ("name", "version", "description"):
        assert entry[key] == claude[key] == codex[key], (name, key)
    assert codex["interface"]["longDescription"] == claude["description"], (name, "longDescription")
    assert codex_market[name]["source"]["path"] == entry["source"], (name, "source path")
    assert codex_market[name]["category"] == codex["interface"]["category"], (name, "category")
print("manifests in sync")
PY

# Codex: install into a throwaway CODEX_HOME, so the real ~/.codex stays unchanged
export CODEX_HOME="$(mktemp -d)"
codex plugin marketplace add "$PWD"
codex plugin add <plugin-name>@ykhfree-plugins
codex plugin list
rm -rf "$CODEX_HOME"; unset CODEX_HOME

# Copilot CLI: add the marketplace, install, then remove
copilot plugin marketplace add "$PWD"
copilot plugin install <plugin-name>@ykhfree-plugins
copilot plugin list --json

# Any agent: list the skills that the skills CLI finds
npx skills add "$PWD" --list
```

The skills CLI parses frontmatter as strict YAML. Claude Code does not, so it hides this error.
If the list shows a `Skipped ... YAML parse error` line, fix that `SKILL.md`.
A common cause is `: ` (colon and space) inside an unquoted `description`. Rewrite the sentence without it.

For Copilot CLI: if a marketplace named `ykhfree-plugins` is already added from GitHub, remove it first or test on a copy with a different marketplace `name`.

Copilot CLI 1.0.10 installs a plugin from a local-path marketplace with `"source": "live"` and `"enabled": false`, so its skills do not load.
This checks only that Copilot parses the files. To check that the skills load, push first and install from `ykhfree/agent-plugins`. Then `copilot plugin list --json` must show `"enabled": true`.

## Git

Use conventional commit messages, such as `feat: add new skill`, `fix: resolve parsing issue`, or `docs: update README`.

## Plugin Notes

### pr-comment
- Requires the GitHub CLI (`gh`), authenticated with `gh auth login`.
- For a GitHub Enterprise host, the skill sets `GH_HOST`. `gh pr` has no `--hostname` option.
- The categorization and priority rules are in `plugins/pr-comment/skills/pr-review/SKILL.md`.

### skillify
- The scripts are Bash. `scripts/validate.sh` also needs Python 3.
- Run the tests of skillify itself from the repository root:
  ```bash
  plugins/skillify/skills/skillify/scripts/run_tests.sh plugins/skillify/skills/skillify
  ```
  The runner runs every test twice: with the current `HOME`, then with `HOME` set to a temporary directory.
- `scripts/validate.sh` gate 9 accepts a skill only under `.claude/skills`, `.agents/skills`, `.codex/skills`, or a Claude Code or Codex plugin cache.
  Run on the source in this repository, the gate fails by design. The installed copy passes.

### explain-ladder
- `scripts/check_diagram.py` needs only Python 3. Level 4 (`scripts/video/`) needs macOS and the venv in `skills/explain-ladder/video.md`.
- Run the tests with the skillify runner from the repository root.
  The video tests find the venv Python through `HOME`, and the runner's second pass changes `HOME`.
  So set `EXPLAIN_VIDEO_PYTHON` first:
  ```bash
  EXPLAIN_VIDEO_PYTHON=~/.venvs/explain-video/bin/python \
    plugins/skillify/skills/skillify/scripts/run_tests.sh plugins/explain-ladder/skills/explain-ladder
  ```
  If the venv Python is missing, the video tests fail. They do not skip.
- To pass gate 9 of `validate.sh`, copy the skill to `<temp dir>/.claude/skills/explain-ladder` and validate the copy.

### jev-delegation
- The skill is documentation only. It has no scripts or tests.
- It needs the `jev` CLI on `PATH` and `TYPESAFE_API_KEY`. The CLI is not published.
- Keep the skill in sync with the CLI: when a `jev` command's flags or output fields change, update `SKILL.md` and raise the plugin version.

### quote-check
- `scripts/quote_check.py` needs only Python 3.10 or later.
- Run the tests with the skillify runner from the repository root:
  ```bash
  plugins/skillify/skills/skillify/scripts/run_tests.sh plugins/quote-check/skills/quote-check
  ```
- `tests/fixtures/sample-repo/` holds small synthetic files. The integration test checks fixed line numbers in them.
  If you edit a fixture, update the line numbers in `tests/integration/eval_fixture_test.sh` and `evals/llm.md`.
- To pass gate 9 of `validate.sh`, copy the skill to `<temp dir>/.claude/skills/quote-check` and validate the copy.

### orchestration-policy
- The skill is documentation only. It has no scripts or tests.
- It is opt-in: its `description` tells the agent to load it only when the user asks. Keep that sentence when you edit the description.
- The subagents it names (`deep-reasoner`, `feature-developer`, `fast-worker`, `fast-explorer`) are not in this repository.
  Keep the "Roles" table, so a user without them can map each role to an agent of their own.
