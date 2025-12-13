---
description: Analyzes all comments on a PR and categorizes unresolved items by priority
argument-hint: [branch|pr-number] [hostname]
---

Analyze all comments on the PR.

## Arguments
- $ARGUMENTS: Branch name or PR number (optional)
  - Examples: `feature/login`, `123`, `github.mycompany.com:feature/login`
  - Format: `[hostname:]<branch|pr-number>`
  - Uses current branch if not specified

## Instructions

### Step 1: Identify PR Information
1. If arguments are provided:
   - If numeric: Use as PR number
   - If string: Use as branch name
   - If `hostname:value` format: Use Enterprise GitHub host
2. If no arguments: Use current branch name

### Step 2: Fetch PR Comments
Fetch all comments using the following commands:
```bash
# Review threads (suggestions/requests)
gh pr view <pr-number> --json reviewThreads --jq '.reviewThreads'

# General PR comments
gh pr view <pr-number> --json comments --jq '.comments'

# PR review comments
gh api repos/{owner}/{repo}/pulls/<pr-number>/comments
```

### Step 3: Categorize Comments
Categorize each comment into the following:
- 🔧 **Fix Required**: Bug reports, logic errors, mandatory changes
- 💬 **Response Needed**: Questions, explanation requests, confirmation needed
- 💡 **Suggestion**: Improvement suggestions, refactoring ideas, optional changes
- 👍 **Praise**: Positive feedback, good code mentions

### Step 4: Assign Priority
- **High**: Bugs, security issues, mandatory changes
- **Medium**: Explanation needed, general questions
- **Low**: Style suggestions, optional improvements

### Step 5: Output Results
Format the output as follows:

```
## PR #<number>: <title>

### 📋 Summary
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
- Use `--hostname` option for Enterprise GitHub
