# Claude Code Plugins Marketplace

A collection of Claude Code plugins for enhancing development workflows.

🔗 **Repository**: [https://github.com/ykhfree/claude-plugins](https://github.com/ykhfree/claude-plugins)

## Available Plugins

### PR Comment Review
Automatically analyzes all comments on GitHub PRs and organizes unresolved items by priority.

### Mutation Harden
Runs PIT mutation testing on Gradle Kotlin projects and closes the test gaps that survived mutants show.

## Installation

### Add the Marketplace
```bash
/plugin marketplace add ykhfree/claude-plugins
```

### Install a Plugin
```bash
# Install PR Comment plugin
/plugin install pr-comment

# Install Mutation Harden plugin
/plugin install mutation-harden
```

## Plugin Documentation

### PR Comment Review

#### Usage

**Basic Usage (Analyze PR for Current Branch)**
```bash
/pr-comment:review
```

**Analyze PR for a Specific Branch**
```bash
/pr-comment:review feature/login
```

**Analyze by PR Number**
```bash
/pr-comment:review 123
```

**Use Different GitHub Host (Enterprise GitHub)**
```bash
/pr-comment:review github.mycompany.com:feature/login
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

### Mutation Harden

#### Usage

The `mutation-harden` skill starts when you ask for mutation testing in natural language. Examples:
- "Run mutation testing on the changes in this branch"
- "PIT 돌려서 살아남은 뮤턴트로 테스트 헛점 보강해줘"

You can also call it directly:
```bash
/mutation-harden:mutation-harden
```

#### Workflow

1. Records a fingerprint of the main code.
2. Finds the changed Kotlin classes against the base branch.
3. Runs PIT on each changed module.
4. Lists survived mutants as gaps.
5. Gives each gap a verdict and asks for your approval before it writes tests.
6. Writes one focused test per approved gap.
7. Verifies each test with a PIT run of that one test method. The run must report the target mutant as `KILLED`.

The skill never changes files under `src/main/` and never commits.

#### Requirements

- Gradle project with Kotlin main code under `src/main/kotlin`
- JUnit 5 tests (Kotest is not supported)
- Gradle wrapper 7.6 or later
- Python 3 and Git installed

## Contributing

More plugins coming soon! Feel free to suggest new plugin ideas or contribute.

## License

MIT
