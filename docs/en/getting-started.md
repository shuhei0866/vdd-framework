# Getting Started

## Overview

This guide walks you through adopting the VDD Framework in your project, from initial setup to your first release cycle. The framework is designed for incremental adoption — start with what you need and add more as you grow comfortable.

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| git | 2.20+ | Version control + worktree support |
| [Claude Code](https://claude.ai/code) | Latest | AI agent for autonomous development |
| jq | 1.6+ | JSON processing in hook scripts |
| bash | 4.0+ | Hook script execution |

Optional (for cloud execution):
- A VPS or cloud instance (any provider)
- tmux (for headless sessions)

## Quick Start

### 1. Initialize the Framework

Run the initialization script in your project root:

```bash
# Clone the framework repository
git clone {{FRAMEWORK_REPO_URL}} /tmp/vdd-framework

# Run the initializer
bash /tmp/vdd-framework/init.sh
```

The `init.sh` script will:

1. Create the `.claude/` directory structure:
   ```
   .claude/
   ├── hooks/
   │   └── guardrails/
   │       ├── worktree-guard.sh    # Blocks edits in main worktree
   │       └── commit-guard.sh      # Blocks dangerous git operations
   ├── settings.json                # Hook configuration
   ├── release-specs/               # Release specifications
   ├── templates/
   │   └── release-spec.md          # Release spec template
   └── skills/
       └── git-worktrees/           # Worktree management skill
   ```

2. Add entries to `.gitignore` (worktree paths, local docs)
3. Create initial `CLAUDE.md` with framework rules
4. Set up hook configurations in `settings.json`

### 2. Verify the Setup

```bash
# Check that hooks are configured
cat .claude/settings.json | jq '.hooks'

# Verify worktree guard is active
# (attempting to edit a file in the main worktree should be blocked)
```

### 3. Create Your First Release

#### Step 1: Define Requirements

Tell Claude Code what you want to build:

```
I want to add a user profile page that shows the user's name and email.
```

#### Step 2: Design Dialogue

Claude Code will discuss the approach with you:
- Architecture decisions
- Release splitting (if needed)
- Tradeoffs

The output is a **release specification** — a document describing what this release does, what it does not do, and what risks exist.

#### Step 3: Autonomous Implementation

Claude Code creates a worktree and implements using TDD:

```bash
# Claude Code handles this automatically:
# 1. Creates worktree: git worktree add ../release-user-profile release/user-profile
# 2. Writes tests first
# 3. Implements to pass tests
# 4. Runs checks
# 5. Self-reviews
# 6. Creates PR
```

#### Step 4: Review and Merge

- Claude Code runs independent review
- You perform exploratory QA
- Merge to `develop`, then promote to `main` when ready

## Adoption Levels

You don't have to adopt everything at once. The framework supports 5 levels of incremental adoption:

| Level | Name | What You Get |
|-------|------|-------------|
| L1 | Safe Development | Worktree isolation — AI can't destroy uncommitted work |
| L2 | Structured Releases | Release workflow with specs and conversation logging |
| L3 | Quality-Enforced | TDD + AI review + enforcement hooks |
| L4 | Vision-Aligned | VDD artifacts + decision authority matrix |
| L5 | Full Autonomous | Cloud execution + debate partner + multi-AI review |

**Recommended starting point**: Level 1. It provides immediate safety benefits with zero process overhead. See [Adoption Levels](./adoption-levels.md) for details on each level.

## Project Structure After Setup

```
your-project/
├── .claude/
│   ├── hooks/
│   │   └── guardrails/
│   │       ├── worktree-guard.sh
│   │       └── commit-guard.sh
│   ├── settings.json
│   ├── release-specs/
│   ├── templates/
│   │   └── release-spec.md
│   ├── skills/
│   │   └── git-worktrees/
│   ├── agents/                  # (L3+) Agent definitions
│   └── agent-memory/            # (L3+) Shared agent memory
├── CLAUDE.md                    # Framework rules + project-specific config
├── VISION.md                    # (L4+) Vision document
├── DECISIONS.md                 # (L4+) Decision log
├── DAILY_SCORE.md               # (L4+) Daily subjective score
└── process/
    ├── VDD.md                   # (L4+) VDD specification
    └── RDD.md                   # RDD specification
```

## Customization

### Configuring Hooks

Edit `.claude/settings.json` to adjust hook behavior:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hook": ".claude/hooks/guardrails/worktree-guard.sh",
        "description": "Block edits in main worktree"
      }
    ]
  }
}
```

### Customizing the Release Spec Template

Edit `.claude/templates/release-spec.md` to match your project's needs. The template should include at minimum:

- Release name and summary
- Expected behavior changes
- Out-of-scope items
- Known risks
- Rollback plan

### Adding Project-Specific Rules

Add your project's conventions to `CLAUDE.md`:

```markdown
## Project-Specific Rules

- Use {{YOUR_PACKAGE_MANAGER}} for dependency management
- Tests go in `__tests__/` directories
- API routes follow REST conventions
```

## Common Workflows

### Starting a New Feature

```
Human: "I want to add dark mode support"
  → Design dialogue (Phase 1)
  → Release spec created
  → AI implements in worktree (Phase 2)
  → AI reviews (Phase 3)
  → Human QA (Phase 4)
  → Merge to develop
```

### Fixing a Bug

```
Human: "Users can't log in on mobile"
  → AI writes reproduction test (TDD)
  → AI fixes bug to pass test
  → AI reviews
  → Human verifies
  → Merge to develop
```

### Splitting a Large Feature

```
Human: "I want a complete notification system"
  → Design dialogue produces release tree:
    [R1] release/notification-schema (DB changes)
    [R2] release/notification-api (API endpoints)
    [R3] release/notification-ui (UI components)
  → Each release follows the full RDD cycle independently
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Hook not blocking edits | Check `.claude/settings.json` hook configuration. Verify script has execute permission (`chmod +x`) |
| Worktree creation fails | Ensure no existing worktree at the same path. Run `git worktree list` to check |
| Claude Code ignores rules | Verify `CLAUDE.md` is in the project root and properly formatted |
| Tests not running | Check that your test runner is configured and the test command works manually |

## Next Steps

- Read [Philosophy](./philosophy.md) to understand the framework's design principles
- Review [Enforcement Levels](./enforcement-levels.md) to understand how rules are enforced
- Explore [Adoption Levels](./adoption-levels.md) to plan your adoption path
- Set up [Cloud Execution](./cloud-execution.md) for headless autonomous development
