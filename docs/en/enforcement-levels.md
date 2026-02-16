# Enforcement Levels

## Overview

The VDD Framework uses a 4-level hierarchy to enforce rules, ranging from hard technical blocks (L5) to documentation-only guidelines (L2). The key design insight: **the higher the blast radius of a violation, the higher the enforcement level should be**.

This hierarchy exists because documentation alone is insufficient for AI agents operating autonomously. An AI agent may not read or follow a documented rule, but it cannot bypass a hook that denies tool execution.

## The Hierarchy

| Level | Label | Mechanism | Bypass Possible? |
|-------|-------|-----------|------------------|
| **L5** | Hook Enforced (deny) | Hook intercepts the tool call and returns `deny` | No. The operation is blocked before execution |
| **L4** | Hook Warning (ask/block) | Hook intercepts and requires user confirmation or blocks session | Only with explicit human approval |
| **L3** | Context Injection | Rule is auto-injected into subagent context at startup | Agent could ignore, but it's in the prompt |
| **L2** | Prompt-only Rule | Rule exists only in CLAUDE.md or documentation | Agent may not read or follow it |

## Level Details

### L5: Hook Enforced (deny)

**Mechanism**: A PreToolUse hook intercepts the tool call. If the condition is violated, the hook returns a `deny` response with an explanation. The tool call never executes.

**When to use**: For rules where violation causes irreversible damage or affects shared state.

**Examples**:

| Hook | What It Blocks | Why L5 |
|------|---------------|--------|
| `worktree-guard.sh` | File edits in main worktree | Protects uncommitted work from destruction |
| `commit-guard.sh` | Force push to main, `--no-verify`, branch switch in main worktree | Prevents irreversible git operations |

**Design**: The AI agent receives an error message explaining *why* the operation was blocked and *what to do instead*. This turns enforcement into guidance.

Example deny response:
```
DENIED: Cannot edit files in the main worktree.
Use the /git-worktrees skill to create a worktree, then edit files there.
Main worktree path: /path/to/project
Attempted edit: /path/to/project/src/index.ts
```

### L4: Hook Warning (ask/block)

**Mechanism**: A hook intercepts the operation and either:
- Returns `ask` with a warning message, requiring user confirmation to proceed
- Returns `block` at session end, preventing completion until conditions are met

**When to use**: For rules that are important but where exceptions may be valid with human judgment.

**Examples**:

| Hook | What It Does | Why L4 |
|------|-------------|--------|
| `migration-guard.sh` | Warns on migration number conflicts | Conflicts are dangerous but may be intentional |
| `review-enforcement/check.sh` | Blocks session end if review not run on `release/*` | Review is mandatory but the human can override if needed |

**Design**: Unlike L5, L4 allows the human to make a judgment call. The hook surfaces the risk; the human decides whether to accept it.

### L3: Context Injection

**Mechanism**: A SubagentStart hook automatically injects rules into the subagent's `additionalContext` field. The rules appear as part of the agent's system prompt.

**When to use**: For rules that apply to autonomous subagents but don't need hard blocking. The rule is present in context, making it likely to be followed, but not technically enforced.

**Examples**:

| Hook | What It Injects | Why L3 |
|------|----------------|--------|
| `subagent-rules/inject.sh` | TDD requirements, worktree rules, review obligations | Subagents need these rules but L5 hooks also protect critical paths |

**Design**: L3 provides defense-in-depth. Even if an L5 hook somehow fails, the rule is also in the agent's context. Conversely, even if the agent ignores the context rule, the L5 hook catches the violation.

### L2: Prompt-only Rule

**Mechanism**: The rule exists in CLAUDE.md, process documentation, or skill definitions. There is no technical enforcement.

**When to use**: For guidelines, best practices, and conventions where violation is inconvenient but not dangerous.

**Examples**:

- "Write commit messages in Japanese"
- "Include diagrams in PR descriptions"
- "Record development insights in the PR"

**Design**: L2 rules set expectations and norms. They work well for style, communication, and workflow preferences. They should not be used for anything where violation could cause data loss or security issues.

## Choosing the Right Level

```
Will violation cause irreversible damage?
├── Yes → L5 (deny)
└── No
    ├── Could violation cause significant problems?
    │   ├── Yes → L4 (ask/block)
    │   └── No
    │       ├── Does an autonomous agent need this rule?
    │       │   ├── Yes → L3 (context injection)
    │       │   └── No → L2 (prompt-only)
    │       └──
    └──
```

### Decision Guidelines

| Criterion | Suggested Level |
|-----------|----------------|
| Destroys uncommitted work | L5 |
| Irreversible git operation | L5 |
| Could break production | L4 or L5 |
| Quality gate (review, tests) | L4 |
| Process rule for subagents | L3 |
| Style, convention, preference | L2 |

## Layered Defense

The levels are designed to work together, not in isolation:

```
L5 (deny)     ─── Last line of defense. Cannot be bypassed.
L4 (ask)      ─── Human judgment checkpoint.
L3 (inject)   ─── Rules in agent context. Defense-in-depth.
L2 (prompt)   ─── Norms and expectations. Sets culture.
```

A well-designed rule often exists at multiple levels simultaneously:

**Example: "Use worktrees for code changes"**
- L5: `worktree-guard.sh` blocks edits in main worktree (technical block)
- L3: Subagent rules inject worktree requirement (context reminder)
- L2: CLAUDE.md documents the rule and its rationale (understanding)

This layered approach ensures that even if one mechanism fails, others catch the issue.

## Creating Custom Hooks

### Hook Script Contract

Hook scripts must:

1. Be executable (`chmod +x`)
2. Accept specific arguments depending on the event type
3. Output a JSON response to stdout

### PreToolUse Hook Response Format

```json
{
  "decision": "deny",
  "reason": "Explanation of why the operation was blocked and what to do instead"
}
```

Valid decisions: `"allow"`, `"deny"`, `"ask"` (with a `message` field for user prompt)

### Stop Hook Response Format

```json
{
  "decision": "block",
  "reason": "Explanation of why the session cannot end"
}
```

Valid decisions: `"allow"`, `"block"`

### SubagentStart Hook Response Format

```json
{
  "additionalContext": "Rules to inject into the subagent's context"
}
```

### Configuration

Hooks are configured in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hook": ".claude/hooks/guardrails/worktree-guard.sh",
        "description": "Block edits in main worktree"
      }
    ],
    "Stop": [
      {
        "hook": ".claude/hooks/review-enforcement/check.sh",
        "description": "Require review on release branches"
      }
    ],
    "SubagentStart": [
      {
        "hook": ".claude/hooks/subagent-rules/inject.sh",
        "description": "Inject rules into subagent context"
      }
    ]
  }
}
```

## Mapping to Adoption Levels

| Adoption Level | Enforcement Levels Used |
|---------------|------------------------|
| L1: Safe Development | L5 (worktree-guard, commit-guard) |
| L2: Structured Releases | L5 + L2 (RDD reminder, templates) |
| L3: Quality-Enforced | L5 + L4 + L3 + L2 (full enforcement stack) |
| L4: Vision-Aligned | Same as L3 + L2 (VDD artifacts) |
| L5: Full Autonomous | All levels fully utilized |

See [Adoption Levels](./adoption-levels.md) for the full breakdown of what each adoption level includes.

## Further Reading

- [Philosophy](./philosophy.md) — "Enforce rules technically, not just document them"
- [Adoption Levels](./adoption-levels.md) — Incremental adoption with enforcement at each level
- [Getting Started](./getting-started.md) — Setup guide including hook configuration
