---
name: review
description: Analyzes all comments on a GitHub PR and categorizes unresolved items by priority. Use when the user asks to review, summarize, or triage the comments on a pull request.
---

Analyze all comments on the PR.

## Input
The user can name a PR target. It is optional.
- Format: `[hostname:]<branch|pr-number>`
- Examples: `feature/login`, `123`, `github.mycompany.com:feature/login`
- If the user names no target, use the current branch.

## Instructions

### Step 1: Identify PR Information
1. If the user named a target:
   - If it is numeric: Use it as the PR number
   - If it is a string: Use it as the branch name
   - If it has the `hostname:value` format: Set `GH_HOST=<hostname>` for every `gh` command
2. If the user named no target: Use the current branch name
3. If you have a branch name, get the PR number: `gh pr view <branch> --json number --jq '.number'`

### Step 2: Analyze PR Changes
Analyze the PR's code changes to understand context before reviewing comments.

Fetch PR metadata and changes:
```bash
# PR basic information (title, description, statistics, labels)
gh pr view <pr-number> --json title,body,additions,deletions,changedFiles,labels

# Changed files with detailed statistics
gh pr view <pr-number> --json files --jq '.files[] | {path: .path, additions: .additions, deletions: .deletions}'

# (Optional) Diff preview for context - limit output for large PRs
gh pr diff <pr-number> | head -n 200
```

Analyze the following:
- **Change magnitude**: Total additions + deletions
- **File types**: Frontend, backend, tests, configuration, documentation
- **Critical files**: Core logic, API endpoints, security-related, database migrations
- **PR labels**: bug, feature, hotfix, breaking-change, etc.

This context will be used in Steps 4-5 for more accurate categorization and prioritization.

### Step 3: Fetch PR Comments
Fetch all comments using the following commands:
```bash
# Review threads (suggestions/requests)
gh pr view <pr-number> --json reviewThreads --jq '.reviewThreads'

# General PR comments
gh pr view <pr-number> --json comments --jq '.comments'

# PR review comments
gh api repos/{owner}/{repo}/pulls/<pr-number>/comments
```

### Step 4: Categorize Comments
Categorize each comment using both comment content and PR change context:

**Categories:**
- 🔧 **Fix Required**: Bug reports, logic errors, mandatory changes
- 💬 **Response Needed**: Questions, explanation requests, confirmation needed
- 💡 **Suggestion**: Improvement suggestions, refactoring ideas, optional changes
- 👍 **Praise**: Positive feedback, good code mentions

**Context-aware categorization:**
- Comments on critical files (API, security, core logic) → More likely to be "Fix Required" or "Response Needed"
- Comments on test files → Can remain "Suggestion" unless urgent
- Comments on bug-labeled PRs → Increase severity of categorization

### Step 5: Assign Priority
Assign priority considering both comment content and PR change context:

**Base priority rules:**
- **High**: Bugs, security issues, mandatory changes
- **Medium**: Explanation needed, general questions
- **Low**: Style suggestions, optional improvements

**Context-aware priority adjustment:**
- Comments on critical files (core logic, API, security) → Escalate priority
- Large PRs (500+ lines changed) with structural comments → High priority
- Breaking changes or hotfix PRs → Escalate related comments
- Test-only changes with style comments → Keep Low priority
- Documentation changes → Generally Medium/Low unless critical

### Step 6: Output Results
Format the output as follows:

```
## PR #<number>: <title>

### 📊 PR Overview
- **Changes**: +X -Y lines across N files
- **Labels**: label1, label2, ...
- **Critical files**: List key changed files (API, core logic, security)

### 📋 Comment Summary
- Total comments: X
- Unresolved: Y
- Resolved: Z

### 🔴 High Priority
| File | Line | Category | Content | Author |
|------|------|----------|---------|--------|

### 🟡 Medium Priority
| File | Line | Category | Content | Author |
|------|------|----------|---------|--------|

### 🟢 Low Priority
| File | Line | Category | Content | Author |
|------|------|----------|---------|--------|

### ✅ Resolved Comments
(List of comments with resolved or outdated status)
```

## Notes
- Move review threads with `isResolved: true` to the "Resolved" section
- Display file path and line number for each comment
- Truncate long comments to first 100 characters
- For Enterprise GitHub, set `GH_HOST=<hostname>` (`gh pr` has no `--hostname` option)
