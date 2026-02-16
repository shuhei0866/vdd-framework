# Adoption Levels

## Overview

The VDD Framework is designed for incremental adoption. You don't need to implement everything on day one. Each level builds on the previous one, adding capabilities and process structure. Start where you are, and move up as your needs grow.

## The 5 Levels

| Level | Name | Value Proposition |
|-------|------|-------------------|
| **L1** | Safe Development | "AI won't destroy uncommitted work" |
| **L2** | Structured Releases | "Structured release workflow with traceability" |
| **L3** | Quality-Enforced | "AI autonomously implements, tests, and reviews" |
| **L4** | Vision-Aligned | "Vision-driven strategic development" |
| **L5** | Full Autonomous | "Fully autonomous end-to-end pipeline" |

---

## L1: Safe Development

**Value**: AI agents cannot accidentally destroy your uncommitted work or make irreversible mistakes in the main worktree.

**When to adopt**: Immediately. This level has zero process overhead and provides immediate safety benefits.

### Components

| Component | Type | Purpose |
|-----------|------|---------|
| `worktree-guard.sh` | Hook (L5 deny) | Blocks all file edits in the main worktree |
| `commit-guard.sh` | Hook (L5 deny) | Blocks force push, `--no-verify`, branch switching in main worktree |
| `git-worktrees` skill | Skill | Creates and manages git worktrees for isolated work |

### How It Works

```
Main worktree (read-only)          Worktree (full access)
├── Your uncommitted changes       ├── AI writes code here
├── Work-in-progress files         ├── AI commits here
└── Safe from AI modifications     └── Isolated from main
```

The worktree guard hook intercepts every Write and Edit operation. If the target path is within the main worktree, the operation is denied with an explanation. The AI agent is directed to create a worktree first.

### Files Added

```
.claude/
├── hooks/guardrails/
│   ├── worktree-guard.sh
│   └── commit-guard.sh
├── skills/git-worktrees/
└── settings.json
```

---

## L2: Structured Releases

**Value**: Every change follows a structured release workflow with specifications, conversation logging, and pre-push checks.

**When to adopt**: When you want more than ad-hoc development — when you need traceability and structure.

### Components (in addition to L1)

| Component | Type | Purpose |
|-----------|------|---------|
| RDD reminder hook | Hook (L2 remind) | Reminds about RDD process when implementation is requested on main branch |
| Release spec template | Template | Standardized format for release specifications |
| Pre-push check command | Command | Runs type checking + linting + tests before push |
| Conversation logger | Hook (SessionEnd) | Auto-saves conversation logs for traceability |
| `release-specs/` directory | Convention | Fixed location for release specifications |

### How It Works

```
Human request → RDD reminder (if on main)
    ↓
Design dialogue → Release spec (from template)
    ↓
Implementation in worktree → Pre-push checks
    ↓
Conversation auto-saved to local docs
```

### Files Added (in addition to L1)

```
.claude/
├── hooks/rdd-reminder/
│   └── remind.sh
├── hooks/conversation-logger/
│   └── log.sh
├── templates/
│   └── release-spec.md
├── release-specs/           # Created per release
└── commands/precheck/
```

---

## L3: Quality-Enforced

**Value**: AI autonomously implements with TDD, reviews its own work, and has quality gates enforced by hooks. This is where AI becomes a reliable implementer, not just a code generator.

**When to adopt**: When you trust the process enough to let AI handle the full implementation-review cycle, and you want quality enforcement rather than quality suggestions.

### Components (in addition to L2)

| Component | Type | Purpose |
|-----------|------|---------|
| Agent definitions | Agents | `code-reviewer`, `implementer` with specialized knowledge |
| TDD rules injection | Hook (L3 inject) | Auto-injects TDD requirements into subagent contexts |
| Subagent rules injection | Hook (L3 inject) | Auto-injects worktree, TDD, and review rules |
| Review enforcement | Hook (L4 block) | Blocks session end on `release/*` if review not executed |
| Migration guard | Hook (L4 ask) | Warns on migration number conflicts |
| Skills | Skills | `/tdd`, `/review-now`, `/release-ready`, `/task-decompose` |
| Agent memory | Convention | Shared memory for agents to accumulate knowledge |

### How It Works

```
Release spec → AI creates worktree
    ↓
TDD cycle (test first → implement → refactor)
    ↓
pnpm check (type check + lint + test)     ← must pass
    ↓
Self-evaluation (/release-ready)           ← quality gate
    ↓
Independent review (/review-now)           ← quality gate
    ↓
Fix issues → re-check → PR
```

The review enforcement hook ensures that `release/*` branches cannot be finalized without running the review process. This is not a suggestion — it is technically enforced.

### Files Added (in addition to L2)

```
.claude/
├── hooks/
│   ├── subagent-rules/inject.sh
│   ├── review-enforcement/check.sh
│   └── guardrails/migration-guard.sh
├── agents/
│   ├── code-reviewer.md
│   └── implementer.md
├── agent-memory/              # Shared across sessions
├── skills/
│   ├── tdd/
│   ├── review-now/
│   ├── release-ready/
│   └── task-decompose/
└── commands/
```

---

## L4: Vision-Aligned

**Value**: Development is driven by a continuously-updated vision. Decisions are logged, authority is explicit, and every release is checked against the vision.

**When to adopt**: When you want strategic alignment — when individual releases should serve a larger purpose, and you want to prevent drift.

### Components (in addition to L3)

| Component | Type | Purpose |
|-----------|------|---------|
| VDD artifacts | Documents | `VISION.md`, `DECISIONS.md`, `DAILY_SCORE.md` |
| Decision authority matrix | Document | Explicit rules for who decides what |
| Reviewer cognitive profile | Document | Optimizes review output for the human reviewer |
| VDD specification | Process doc | Full VDD methodology documentation |
| Release spec checklist | Convention | 8-point checklist including vision alignment |

### How It Works

```
Vision document ← updated through feedback meetings
    ↓
Decisions logged ← with context, rationale, supersession chains
    ↓
Release specs ← checked against vision (8-point checklist)
    ↓
Daily score ← subjective momentum tracking
```

### Files Added (in addition to L3)

```
project-root/
├── VISION.md
├── DECISIONS.md
├── DAILY_SCORE.md
└── process/
    └── VDD.md

.claude/
└── reviewer-profile.md
```

---

## L5: Full Autonomous

**Value**: The complete autonomous development pipeline. AI implements, reviews, and merges without human intervention during the execution phase. Cloud execution enables 24/7 development. Multiple AI perspectives ensure quality.

**When to adopt**: When you have high confidence in the framework's guardrails and want maximum AI autonomy during execution phases.

### Components (in addition to L4)

| Component | Type | Purpose |
|-----------|------|---------|
| Cloud execution setup | Infrastructure | VPS for headless Claude Code execution |
| Debate partner | Integration | External AI for vision-alignment verification |
| Multi-AI review | Process | Different AI models review the same work |
| Notification system | Integration | Discord/Slack notifications for async coordination |
| External approver | Integration | Independent AI/human approver for PR merges |

### How It Works

```
[Local] Design dialogue → Release spec → git push
    ↓
[Cloud VPS] Claude Code headless execution
    ↓
TDD → review → PR creation → notify approver
    ↓
[Approver] Independent review → approve
    ↓
[Cloud VPS] Confirm approval → merge to develop
    ↓
[Local/Mobile] Human QA on preview → promote to main
```

Multiple releases can execute in parallel on the VPS using separate tmux sessions and worktrees, as long as they don't modify the same files.

### Files Added (in addition to L4)

```
.claude/
├── cloud/
│   ├── scripts/
│   │   ├── notify.sh           # Notification webhook
│   │   └── hook-stop-notify.sh # Session end notification
│   ├── setup.sh                # VPS initial setup
│   └── .env.example            # Required environment variables
└── skills/
    └── codex-review/           # External AI review integration

process/
└── cloud-execution.md
```

---

## Migration Path

### L1 → L2

Add the release spec template and RDD reminder hook. Start writing release specs for your changes. No code changes required.

### L2 → L3

Define your agents (`code-reviewer`, `implementer`). Add TDD enforcement and review hooks. Start running `/release-ready` and `/review-now` before creating PRs.

### L3 → L4

Create `VISION.md`, `DECISIONS.md`, and `DAILY_SCORE.md`. Start holding feedback meetings. Add the 8-point release spec checklist.

### L4 → L5

Set up cloud execution infrastructure. Configure notification webhooks. Integrate an external AI for debate and multi-perspective review.

## Choosing Your Starting Level

| Your Situation | Recommended Level |
|---------------|-------------------|
| Just starting with AI-assisted development | **L1** |
| Want structured workflow without heavy process | **L2** |
| Want AI to handle full implementation cycle | **L3** |
| Need strategic alignment across releases | **L4** |
| Want maximum AI autonomy + cloud execution | **L5** |

**General advice**: Start with L1. Use it for a week. If you find yourself wanting more structure, move to L2. Repeat until you find the right level for your project.

## Further Reading

- [Philosophy](./philosophy.md) — Core design principles
- [Enforcement Levels](./enforcement-levels.md) — How rules are technically enforced at each level
- [Getting Started](./getting-started.md) — Initial setup guide
