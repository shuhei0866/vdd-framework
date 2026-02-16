# Core Beliefs & Design Principles

## Overview

The VDD Framework is built on a set of core beliefs about how AI-autonomous development should work. These principles inform every design decision — from hook enforcement levels to branch strategies.

## Principle 1: Enforce Rules Technically, Not Just Document Them

Documentation is necessary but insufficient. Rules that exist only in text are rules that will be broken — especially by AI agents operating autonomously.

The VDD Framework implements a **5-level enforcement hierarchy** (see [Enforcement Levels](./enforcement-levels.md)):

- **L5 (Hook Enforced)**: Critical rules are technically blocked. An AI agent *cannot* edit files in the main worktree, regardless of what its prompt says.
- **L4 (Hook Warning)**: Important rules trigger user confirmation before proceeding.
- **L3 (Context Injection)**: Rules are automatically injected into subagent contexts at startup.
- **L2 (Prompt-only)**: Rules exist in configuration files. No technical enforcement.

The key insight: **the higher the blast radius of a violation, the higher the enforcement level should be**. Destroying uncommitted work warrants L5. Style preferences can stay at L2.

## Principle 2: Maximum Autonomy Within Enforced Boundaries

AI agents are most productive when they can operate freely — but freedom without boundaries leads to mistakes that are expensive to reverse. The framework resolves this tension by:

1. **Defining clear boundaries** (worktree isolation, branch protection, scope constraints)
2. **Enforcing those boundaries technically** (hooks that block, not warn)
3. **Granting full autonomy within those boundaries** (YOLO mode for subagents in isolated worktrees)

This means an AI agent working on a release branch in a dedicated worktree can read, write, test, commit, and review — without asking permission for each step. The boundaries ensure it cannot accidentally destroy work on other branches or push directly to production.

## Principle 3: Separation of Strategy and Execution

[VDD](./VDD.md) (Vision-Driven Development) handles **what to build and why**. [RDD](./RDD.md) (Release-Driven Development) handles **how to build and deliver it**.

This separation matters because:

- **Strategy changes at a different cadence than execution.** Vision evolves through human reflection; implementation happens in focused sprints.
- **Different actors own different layers.** Humans own vision and QA. AI owns implementation and self-review.
- **Coupling strategy to execution creates confusion.** When "what should we build?" and "how should we build it?" are mixed, both suffer.

In practice: VDD produces decisions and direction. RDD consumes them as inputs to release specifications, then executes autonomously.

## Principle 4: Git Worktree Isolation

**All code changes happen in git worktrees, never in the main working tree.**

This is not a suggestion — it is enforced at L5 (hook deny). The main worktree is read-only for AI agents.

Why this matters:

- **Uncommitted work protection**: The main worktree may contain work-in-progress from other branches. Switching branches or discarding changes can destroy that work silently.
- **Parallel safety**: Multiple AI agents can work on different releases simultaneously, each in their own worktree, without file conflicts.
- **Clean separation**: The main worktree serves as a stable reference point for reading code and running diagnostics. It is never in a dirty state.

## Principle 5: The Importance of Kata (Patterns)

In martial arts, *kata* are formalized sequences of movements practiced until they become automatic. The VDD Framework applies the same concept to AI-autonomous development:

- **Release phases are kata**: Requirements, design dialogue, implementation, review, merge — the same sequence every time.
- **TDD is a kata**: Red, green, refactor — never skipped, never reordered.
- **Review is a kata**: Self-evaluation, independent review, multi-perspective review — always in that order.

Why kata matter for AI agents:

1. **Consistency reduces errors.** An AI agent that follows the same steps every time is less likely to skip critical checks.
2. **Patterns are composable.** A well-defined release kata can be parallelized, delegated to subagents, or executed headlessly on a VPS.
3. **Deviations become visible.** When the standard pattern is clear, any deviation stands out — both to humans reviewing the work and to enforcement hooks.

The framework does not prescribe *what* to build. It prescribes *how the process of building should flow*. The kata are the process.

## Principle 6: Humans Judge, AI Executes

The framework draws a clear line between judgment and execution:

| Responsibility | Owner | Examples |
|---------------|-------|---------|
| **Vision** | Human | What to build, what *not* to build, quality standards |
| **Design decisions** | Human + AI | Architecture, release splitting, tradeoffs |
| **Implementation** | AI | Code, tests, refactoring |
| **Code review** | AI | Multi-perspective automated review |
| **QA** | Human | Exploratory testing, "does this feel right?" |
| **Release decision** | Human | Promote to production or not |

AI agents have full autonomy for execution within defined scope. Humans retain authority over all strategic decisions. See [Decision Authority Matrix](./decision-authority-matrix.md) for the full breakdown.

## Principle 7: Multi-Perspective Review Over Single-Point Review

A single reviewer — human or AI — has blind spots. The framework addresses this through:

- **Self-evaluation**: The implementing agent evaluates its own work first
- **Independent AI review**: A separate AI agent (different context, different perspective) reviews the code
- **External AI review**: A different AI model reviews the work, catching different classes of issues
- **Human QA**: Exploratory testing that no automated review can replace

This layered approach (see [QA Layers](./qa-layers.md)) ensures that different types of issues are caught at different stages, rather than relying on a single review step to catch everything.

## How These Principles Connect

```
Philosophy                    Implementation
─────────────────────────────────────────────────
Enforce technically      →    Hook enforcement levels (L5-L2)
Autonomy + boundaries    →    Worktree isolation + YOLO mode
Strategy / execution     →    VDD / RDD separation
Worktree isolation       →    worktree-guard hook (L5 deny)
Kata (patterns)          →    Standard phases, TDD, review steps
Humans judge, AI acts    →    Decision authority matrix
Multi-perspective review →    3-layer QA model
```

Each principle reinforces the others. Technical enforcement makes autonomy safe. Worktree isolation enables parallel execution. Kata make enforcement predictable. The whole is greater than the sum of its parts.

## Further Reading

- [VDD Specification](./VDD.md) — Vision-Driven Development
- [RDD Specification](./RDD.md) — Release-Driven Development
- [Enforcement Levels](./enforcement-levels.md) — L5 deny to L2 remind hierarchy
- [Decision Authority Matrix](./decision-authority-matrix.md) — Who decides what
- [Adoption Levels](./adoption-levels.md) — Incremental adoption from L1 to L5
