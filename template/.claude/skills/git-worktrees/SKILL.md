---
name: git-worktrees
description: Use when starting feature work that needs isolation from current workspace or before executing implementation plans - creates isolated git worktrees with smart directory selection and safety verification
---

# Using Git Worktrees

## Overview

Git worktrees create isolated workspaces sharing the same repository, allowing work on multiple branches simultaneously without switching.

**Core principle:** Systematic directory selection + safety verification = reliable isolation.

**Announce at start:** "I'm using the git-worktrees skill to set up an isolated workspace."

## Directory Selection Process

Follow this priority order:

### 1. Check Existing Directories

```bash
# Check in priority order
ls -d .worktrees 2>/dev/null     # Preferred (hidden)
ls -d worktrees 2>/dev/null      # Alternative
```

**If found:** Use that directory. If both exist, `.worktrees/` wins.

### 2. Check CLAUDE.md

```bash
grep -i "worktree.*director" CLAUDE.md 2>/dev/null
```

**If preference specified:** Use it without asking.

### 3. Ask User

If no directory exists and no CLAUDE.md preference:

```
No worktree directory found. Where should I create worktrees?

1. .worktrees/ (project-local, hidden)
2. ~/.config/superpowers/worktrees/<project-name>/ (global location)

Which would you prefer?
```

## Safety Verification

### For Project-Local Directories (.worktrees or worktrees)

**MUST verify directory is ignored before creating worktree:**

```bash
# Check if directory is ignored (respects local, global, and system gitignore)
git check-ignore -q .worktrees 2>/dev/null || git check-ignore -q worktrees 2>/dev/null
```

**If NOT ignored:**

1. Add appropriate line to .gitignore
2. Commit the change
3. Proceed with worktree creation

**Why critical:** Prevents accidentally committing worktree contents to repository.

### For Global Directory (~/.config/superpowers/worktrees)

No .gitignore verification needed - outside project entirely.

## Creation Steps

### 1. Detect Project Name

```bash
project=$(basename "$(git rev-parse --show-toplevel)")
```

### 2. Determine Base Branch

Determine the base branch for the worktree:

- **If a base branch is specified via arguments**: Use that branch
- **If decomposing sub-tasks within a VDD `release/*` branch**: The release branch is the base
- **Otherwise**: main (default)

```bash
# Determine base branch
# Specified via argument: /git-worktrees feature/chat/api --base release/chat-feature
# Default: main
BASE_BRANCH="${SPECIFIED_BASE:-main}"
```

### 3. Sync Base Branch with Remote

Fetch the latest state of the base branch before creating the worktree. If the local branch is stale, you may branch from outdated code and miss recently added files or changes.

```bash
# Fetch from remote if the branch exists there (skip for local-only branches)
git fetch origin "$BASE_BRANCH" 2>/dev/null
```

- Remote branch exists → branch from `origin/$BASE_BRANCH` (always up-to-date)
- Local-only branch (e.g., unpushed `release/*`) → branch from local `$BASE_BRANCH`

### 4. Create Worktree

```bash
# Determine full path
case $LOCATION in
  .worktrees|worktrees)
    path="$LOCATION/$BRANCH_NAME"
    ;;
  ~/.config/superpowers/worktrees/*)
    path="~/.config/superpowers/worktrees/$project/$BRANCH_NAME"
    ;;
esac

# Branch from remote if available, otherwise from local
if git rev-parse --verify "origin/$BASE_BRANCH" >/dev/null 2>&1; then
  git worktree add "$path" -b "$BRANCH_NAME" "origin/$BASE_BRANCH"
else
  git worktree add "$path" -b "$BRANCH_NAME" "$BASE_BRANCH"
fi
cd "$path"
```

### 5. Run Project Setup

Auto-detect and run appropriate setup:

```bash
# Node.js
if [ -f package.json ]; then npm install; fi

# Rust
if [ -f Cargo.toml ]; then cargo build; fi

# Python
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi

# Go
if [ -f go.mod ]; then go mod download; fi
```

### 6. Verify Clean Baseline

Run tests to ensure worktree starts clean:

```bash
# Examples - use project-appropriate command
npm test
cargo test
pytest
go test ./...
```

**If tests fail:** Report failures, ask whether to proceed or investigate.

**If tests pass:** Report ready.

### 7. Report Location

```
Worktree ready at <full-path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| `.worktrees/` exists | Use it (verify ignored) |
| `worktrees/` exists | Use it (verify ignored) |
| Both exist | Use `.worktrees/` |
| Neither exists | Check CLAUDE.md → Ask user |
| Directory not ignored | Add to .gitignore + commit |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |

## Common Mistakes

### Skipping ignore verification

- **Problem:** Worktree contents get tracked, pollute git status
- **Fix:** Always use `git check-ignore` before creating project-local worktree

### Assuming directory location

- **Problem:** Creates inconsistency, violates project conventions
- **Fix:** Follow priority: existing > CLAUDE.md > ask

### Proceeding with failing tests

- **Problem:** Can't distinguish new bugs from pre-existing issues
- **Fix:** Report failures, get explicit permission to proceed

### Hardcoding setup commands

- **Problem:** Breaks on projects using different tools
- **Fix:** Auto-detect from project files (package.json, etc.)

## Example Workflow

### VDD Release Branch Creation

```
You: I'm using the git-worktrees skill to set up an isolated workspace.

[Check .worktrees/ - exists]
[Verify ignored - git check-ignore confirms .worktrees/ is ignored]
[Base branch: main (default)]
[Create worktree: git worktree add .worktrees/chat-feature -b release/chat-feature main]
[Run dependency install]
[Run tests - all passing]

Worktree ready at /project/.worktrees/chat-feature
Tests passing (N tests, 0 failures)
Ready to implement chat-feature release
```

### Sub-task Worktree (Release Branch as Base)

```
You: I'm using the git-worktrees skill to set up an isolated workspace.

[Check .worktrees/ - exists]
[Verify ignored - confirmed]
[Base branch: release/chat-feature (specified)]
[Create worktree: git worktree add .worktrees/chat-api -b feature/chat/api release/chat-feature]
[Run dependency install]
[Run tests - all passing]

Worktree ready at /project/.worktrees/chat-api
Base: release/chat-feature
Tests passing (N tests, 0 failures)
Ready to implement chat API
```

## Red Flags

**Never:**
- Create worktree without verifying it's ignored (project-local)
- Skip baseline test verification
- Proceed with failing tests without asking
- Assume directory location when ambiguous
- Skip CLAUDE.md check

**Always:**
- Follow directory priority: existing > CLAUDE.md > ask
- Verify directory is ignored for project-local
- Auto-detect and run project setup
- Verify clean test baseline

## Integration

**Called by:**
- Any skill needing isolated workspace

**Pairs with:**
- Task decompose skill - Work happens in this worktree
- Implementation workflows - Isolation for safe development
