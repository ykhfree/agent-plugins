# Claude Code Plugins Marketplace

A collection of Claude Code plugins for enhancing development workflows.

🔗 **Repository**: [https://github.com/ykhfree/claude-plugins](https://github.com/ykhfree/claude-plugins)

## Available Plugins

### PR Comment Review
Automatically analyzes all comments on GitHub PRs and organizes unresolved items by priority.

## Installation

### Add the Marketplace
```bash
/plugin marketplace add ykhfree/claude-plugins
```

### Install a Plugin
```bash
# Install PR Comment Review plugin
/plugin install pr-comment-review

# More plugins coming soon...
```

## Plugin Documentation

### PR Comment Review

#### Usage

**Basic Usage (Analyze PR for Current Branch)**
```bash
/pr-comment-review
```

**Analyze PR for a Specific Branch**
```bash
/pr-comment-review feature/login
```

**Analyze by PR Number**
```bash
/pr-comment-review 123
```

**Use Different GitHub Host (Enterprise GitHub)**
```bash
/pr-comment-review github.mycompany.com:feature/login
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

More plugins coming soon! Feel free to suggest new plugin ideas or contribute.

## License

MIT
