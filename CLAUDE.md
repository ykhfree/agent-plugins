# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository is a Claude Code plugin marketplace that hosts multiple plugins for enhancing development workflows. Each plugin is independently versioned and maintained in its own subdirectory under `plugins/`.

**Repository**: https://github.com/ykhfree/claude-plugins

Current plugins:
- **pr-comment**: Analyzes GitHub PR comments and categorizes them by priority

## Architecture

### Marketplace Structure
```
/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace definition with all plugins
├── plugins/
│   ├── pr-comment/               # Individual plugin directory
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json       # Plugin-specific metadata
│   │   └── commands/
│   │       └── review.md
│   └── [future-plugins]/         # Additional plugins go here
├── README.md
└── CLAUDE.md
```

### Plugin Structure
Each plugin under `plugins/` follows this structure:
- `{plugin-name}/`
  - `.claude-plugin/plugin.json`: Plugin definition (name, version, description, requirements)
  - `commands/` or `skills/`: Command/skill definitions
  - Optional: `README.md` for plugin-specific documentation

### Plugin System Architecture
1. **Marketplace Definition**: Root `.claude-plugin/marketplace.json` lists all available plugins with their source paths
2. **Plugin Isolation**: Each plugin in `plugins/{plugin-name}/` is self-contained with its own metadata and commands
3. **Command Definition**: `commands/*.md` or `skills/*.md` files define functionality to be executed by Claude Code
4. **Metadata**: Each plugin's `.claude-plugin/plugin.json` contains version, dependencies, and description

### Command Specification Format
Each command consists of frontmatter (YAML) and Markdown body:
- Frontmatter: `description`, `argument-hint`, and other metadata
- Body: Detailed instructions, step-by-step execution guide, output format

## Development Commands

### Plugin Testing
```bash
# Install plugin locally
/plugin marketplace add ykhfree/claude-plugins
/plugin install pr-comment

# Test command execution (format: /plugin-name:command-name)
/pr-comment:review                    # Current branch
/pr-comment:review feature/login      # Specific branch
/pr-comment:review 123                # PR number
```

### Git Operations
```bash
# Add all changes
git add .

# Commit with conventional commit format
git commit -m "feat: add new command"
git commit -m "fix: resolve command parsing issue"
git commit -m "docs: update README"

# Push changes
git push origin main
```

## Plugin Development Guidelines

### Creating a New Plugin
1. Create a new directory under `plugins/`:
   ```bash
   mkdir -p plugins/{plugin-name}/.claude-plugin
   mkdir -p plugins/{plugin-name}/commands  # or skills/
   ```

2. Create `plugins/{plugin-name}/.claude-plugin/plugin.json`:
   ```json
   {
     "name": "plugin-name",
     "version": "1.0.0",
     "description": "Plugin description",
     "author": {"name": "Author Name"},
     "requirements": {"tools": ["required-cli-tools"]}
   }
   ```

3. Create command files in `plugins/{plugin-name}/commands/`:
   - Add frontmatter with `description` and `argument-hint`
   - Write detailed instructions in Markdown body
   - Include step-by-step execution guide
   - Specify expected input/output format

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

### Adding Commands to Existing Plugin
1. Create `{command-name}.md` in the plugin's `commands/` directory
2. Follow the command specification format
3. Update plugin version if necessary
4. Sync version in both `plugin.json` and `marketplace.json`

### Command Instruction Best Practices
- **Provide specific bash commands**: Precise commands that Claude can execute
- **Define clear output format**: Present examples such as tables, section structures, etc.
- **Include error handling**: Failure cases and response methods
- **Specify external tool dependencies**: Required tools such as `gh`, `git`, etc.

### Command Naming Best Practices
Commands are invoked as `/plugin-name:command-name`. To avoid redundancy:
- **Keep command names short**: Use `review.md` instead of `pr-comment-review.md`
- **Keep plugin names concise**: `pr-comment` is better than `pr-comment-review`
- **Example**: Plugin `pr-comment` with command `review.md` → `/pr-comment:review`
- **Avoid duplication**: Don't name the command file the same as the plugin name

### Plugin Metadata Synchronization
When modifying a plugin, ensure these files are synchronized:
1. `plugins/{plugin-name}/.claude-plugin/plugin.json`: version, description, requirements
2. `.claude-plugin/marketplace.json`: Corresponding entry in the plugins array
3. `README.md`: Update the "Available Plugins" section and plugin documentation

## Plugin-Specific Notes

### pr-comment Plugin

#### GitHub CLI Integration
This plugin fetches PR data using GitHub CLI (`gh`):

```bash
# Review threads
gh pr view <pr-number> --json reviewThreads --jq '.reviewThreads'

# PR comments
gh pr view <pr-number> --json comments --jq '.comments'

# Review comments (API)
gh api repos/{owner}/{repo}/pulls/<pr-number>/comments
```

Enterprise GitHub support:
```bash
gh pr view <pr-number> --hostname github.mycompany.com
```

#### PR Comment Categorization Logic
Categorization system that the review command implements:

**Categories:**
- 🔧 **Fix Required**: Bugs, logic errors, mandatory changes
- 💬 **Response Needed**: Questions, explanation requests
- 💡 **Suggestion**: Improvement suggestions, refactoring
- 👍 **Praise**: Positive feedback

**Priority Levels:**
- **High**: Bugs, security issues, mandatory changes
- **Medium**: Explanation needed, general questions
- **Low**: Style suggestions, optional improvements

**Resolution Status:**
- Unresolved: `isResolved: false` or no resolution marker
- Resolved: `isResolved: true` or markers such as "Resolved", "Outdated", etc.
