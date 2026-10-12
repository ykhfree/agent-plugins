# AGENTS.md

This file gives guidance to AI coding agents (Claude Code, Codex, GitHub Copilot, and others) that work in this repository.
`CLAUDE.md` imports this file, so keep all guidance here.

## Project Overview

This repository is a plugin marketplace that several AI coding agents can install from.
Each plugin is versioned on its own and lives in its own directory under `plugins/`.

**Repository**: https://github.com/ykhfree/agent-plugins

Current plugins:
- **pr-comment**: Analyzes GitHub PR comments and categorizes them by priority

## Compatibility

One layout serves every supported agent. Tested on Claude Code 2.1.296, Codex CLI 0.142.3, and Copilot CLI 1.0.10.

| File | Claude Code | Codex | Copilot CLI |
|------|-------------|-------|-------------|
| `.claude-plugin/marketplace.json` | Native | Read as a legacy-compatible marketplace | Read (fallback location) |
| `plugins/<name>/.claude-plugin/plugin.json` | Native | Read (Claude-compatible manifest) | Read (legacy manifest location) |
| `plugins/<name>/skills/<skill>/SKILL.md` | Native | Native | Native |

Agents without a plugin system can install the skills directly with `npx skills add ykhfree/agent-plugins`.
The skills follow the open [Agent Skills](https://agentskills.io/specification) format.

Do not add a root `plugin.json` (Agent Plugins format). Codex 0.142.3 ignores it and builds its manifest from the marketplace entry, so it only adds a second copy of the metadata to keep in sync.

## Structure

```
/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace definition with all plugins
├── plugins/
│   └── pr-comment/
│       ├── .claude-plugin/
│       │   └── plugin.json       # Plugin metadata
│       └── skills/
│           └── review/
│               └── SKILL.md      # Skill instructions
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
3. Write `plugins/{plugin-name}/skills/{skill-name}/SKILL.md` by the portability rules above.
4. Register the plugin in `.claude-plugin/marketplace.json`:
   ```json
   {
     "name": "plugin-name",
     "source": "./plugins/{plugin-name}",
     "description": "Plugin description",
     "version": "1.0.0",
     "author": {"name": "Author Name"}
   }
   ```
5. Add the plugin to the "Available Plugins" section of `README.md`.

## Naming

In Claude Code, a skill runs as `/plugin-name:skill-name`. Keep both names short and do not repeat the plugin name in the skill name.
Example: plugin `pr-comment` with skill `review` runs as `/pr-comment:review`.

## Metadata Synchronization

When you change a plugin, keep these in sync:
1. `plugins/{plugin-name}/.claude-plugin/plugin.json`: `version`, `description`
2. `.claude-plugin/marketplace.json`: the matching entry. Its `version` must equal the `plugin.json` version.
   Claude Code and Codex read the version from `plugin.json`; Copilot CLI reads it from the marketplace entry.
3. `README.md`: the "Available Plugins" section and the plugin documentation

Raise the version on every change that users should receive. Claude Code and Codex keep an installed plugin at its version until the version changes.

## Verification

Run these checks before you push:

```bash
# Claude Code: validate the marketplace and each plugin
claude plugin validate .
claude plugin validate ./plugins/<plugin-name>

# Codex: add the local marketplace, install, then remove
codex plugin marketplace add "$PWD"
codex plugin add <plugin-name>@ykhfree-plugins
codex plugin list

# Copilot CLI: add the local marketplace, install, then remove
copilot plugin marketplace add "$PWD"
copilot plugin install <plugin-name>@ykhfree-plugins
copilot plugin list

# Any agent: list the skills that the skills CLI finds
npx skills add "$PWD" --list
```

If a marketplace named `ykhfree-plugins` is already added from GitHub, remove it first or test on a copy with a different marketplace `name`.

## Git

Use conventional commit messages, such as `feat: add new skill`, `fix: resolve parsing issue`, or `docs: update README`.

## Plugin Notes

### pr-comment
- Requires the GitHub CLI (`gh`), authenticated with `gh auth login`.
- For a GitHub Enterprise host, the skill sets `GH_HOST`. `gh pr` has no `--hostname` option.
- The categorization and priority rules are in `plugins/pr-comment/skills/review/SKILL.md`.
