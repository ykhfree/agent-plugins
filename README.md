# Agent Plugins Marketplace

A collection of plugins for AI coding agents. One repository works with Claude Code, Codex, GitHub Copilot CLI, and any agent that supports [Agent Skills](https://agentskills.io).

🔗 **Repository**: [https://github.com/ykhfree/agent-plugins](https://github.com/ykhfree/agent-plugins)

## Available Plugins

### PR Comment Review (`pr-comment`)
Analyzes all comments on a GitHub PR and organizes unresolved items by priority.

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
The agent picks the `review` skill from its description.

In Claude Code, you can also call it directly:
```bash
/pr-comment:review                                  # PR for the current branch
/pr-comment:review feature/login                    # PR for a specific branch
/pr-comment:review 123                              # PR number
/pr-comment:review github.mycompany.com:feature/login   # GitHub Enterprise host
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

## Contributing

To add a plugin, follow the portability rules in [AGENTS.md](AGENTS.md).

## License

MIT
