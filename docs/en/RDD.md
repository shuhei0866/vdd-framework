# RDD — Release-Driven Development

## Overview

Release-Driven Development (RDD) is a methodology where the **deployable behavior change** — not the commit, not the PR — is the unit of work. RDD answers the question: **"How do we deliver value reliably?"**

RDD is the execution layer of the framework. It pairs with [VDD](./VDD.md) (Vision-Driven Development), which handles strategy. Together, they form a complete AI-autonomous development pipeline.

## Core Principles

1. **The release is the unit of work.** Commits and PRs are means, not ends.
2. **Review behavior, not code.** The review target is the change in observable behavior, not the code diff.
3. **TDD supports the release.** Test-Driven Development is the implementation technique within each release cycle.
4. **Every release has explicit scope and risk.** No implicit assumptions about what changed or what might break.

## Role Distribution

### Human Responsibilities

| Phase | Responsibility |
|-------|---------------|
| Requirements | Define what to achieve (goals, user stories, constraints) |
| Design dialogue | Participate in shaping the implementation approach |
| QA | Final verification of value and quality |

### AI Responsibilities

| Phase | Responsibility |
|-------|---------------|
| Implementation | Write code, following TDD |
| Testing | Create and maintain automated tests |
| Self-evaluation | Assess own work before review |
| Review | Conduct and coordinate multi-perspective reviews |

## Standard Phases

### Phase 0: Requirements (Human)

The human states the essential purpose:
- User stories or goals
- Constraints and boundaries
- What success looks like

Implementation details are **not** included at this stage.

### Phase 1: Design Dialogue (Human + AI)

Based on requirements, the human and AI discuss the implementation approach:
- Architecture decisions
- Release splitting (if the work should be divided)
- Tradeoffs and alternatives

**Output**: Release specification (stored at a configurable path, e.g., `{{RELEASE_SPECS_DIR}}/{release-name}.md`)

When the work is split into multiple releases, a **release tree** is produced to visualize the structure (see [Release Tree Notation](#release-tree-notation) below).

### Phase 2: Autonomous Implementation (AI)

The AI works in an isolated worktree on a `release/*` branch:

1. Create worktree and release branch
2. Commit the release specification
3. Implement using TDD (test-first, strictly enforced)
4. Stay within the scope defined by the release specification

### Phase 3: Self-Evaluation + Independent Review (AI)

1. Run project checks (type checking, linting, tests)
2. Execute self-evaluation (release readiness check)
3. Run independent AI review (separate context, different perspective)
4. Optionally run external AI review (different model, different blind spots)
5. Fix any issues found, re-run checks
6. Create PR with review results, reports, and development insights

### Phase 4: Merge + QA (AI merge, Human QA)

1. PR targets the integration branch (`develop`)
2. An independent reviewer (human or AI approver) reviews and approves the PR
3. The implementing agent confirms approval, then merges
4. Human performs exploratory QA on the integration environment
5. Human triggers promotion from integration to production

## Required Artifacts

Every release must produce:

| Artifact | Description |
|----------|-------------|
| Release specification | What this release does, what it does not do, and what risks exist |
| Expected behavior | How the system should behave after the release |
| Out-of-scope declaration | What is explicitly *not* part of this release |
| Risk disclosure | Known risks and mitigation strategies |

## Release Granularity Rules

- **1 release = 1 independently deployable change**
- Must be rollback-capable
- Must not have unnecessary dependencies on other releases
- If a release includes database migrations, no other concurrent release should include migrations (to avoid schema conflicts)

## Release Classification (2-Layer Model)

### Layer 1: RDD Release (All `release/*` branches)

Every `release/*` branch merge is an RDD release. This includes releases with no version tag.

### Layer 2: Version-Tagged Release (Selective)

| Classification | Target | Version Tag | Changelog | Docs Update |
|---------------|--------|-------------|-----------|-------------|
| developer-only | Refactoring, CI, docs, internal improvements | None | None | Not required |
| user-facing (bugfix) | User-visible bug fixes | patch | Created | Not required |
| user-facing (feature) | New features | minor | Created | Required |
| user-facing (breaking) | Breaking changes / major milestones | major | Created | Required |

### Classification Decision Tree

1. **Does it include user-visible behavior changes?** No → developer-only (no tag)
2. **Bug fix or new feature?** Bug fix → patch, Feature → minor
3. **Does documentation need updating?** Required for minor+ user-facing releases
4. **Batching**: Multiple RDD releases can be grouped into a single semantic version when they form a meaningful unit

## Release Tree Notation

When requirements are split into multiple releases during Phase 1 (design dialogue), the structure is visualized using a text-based release tree.

### Purpose

- Visualize "how many releases exist and what their ordering is" at any point during the dialogue
- Enable agreement on splitting, merging, and reordering releases before specifications are written
- Ensure structural consensus before committing to implementation

### Format

```
[R1] release/<name>
|    <one-line summary>
|
+---> [R2] release/<name>
|          <one-line summary>
|
+---> [R3] release/<name>
           <one-line summary>
           |
           +---> [R3a] release/<name>
           |          <one-line summary>
           |
           +---> [R3b] release/<name>
                      <one-line summary>
```

### Rules

- **Numbers are temporal**: R1 is released before R2, R2 before R3
- **Suffixes indicate branching**: R3 splits into R3a, R3b (can execute in parallel)
- **Arrows indicate dependencies**: The target of `+-->` is the dependent release
- **Sequential**: Parent to single child in a line (R1 → R2 → R3)
- **Parallel**: Same parent to multiple children (R1 → R2 and R1 → R3)

### Sequential Example

```
[R1] release/data-schema
|    DB: Add new table
|
+---> [R2] release/data-ui
           UI: Selection and filtering
           |
           +---> [R3] release/data-integration
                      Integrate with core feature
```

### Parallel Example

```
[R1] release/data-schema
|    DB: Add new table
|
+---> [R2] release/data-ui
|          UI: Selection and filtering
|
+---> [R3] release/data-api
           API: CRUD endpoints
```

### Usage

- AI outputs the release tree during design dialogue; human agrees on the structure
- Each release in the tree gets its own release specification
- PR descriptions include the release tree (optionally converted to a diagram)

## TDD Integration

**TDD is mandatory within every RDD release cycle.** Implementation code must not be written before tests.

### TDD Cycle

1. **Write a failing test** that describes the expected behavior
2. **Confirm it fails** (proves the behavior does not yet exist)
3. **Write the minimum implementation** to make the test pass
4. **Refactor** as needed while keeping tests green

### For Bug Fixes

1. Write a test that reproduces the bug
2. Confirm the test fails (proves the bug exists)
3. Fix the bug so the test passes

## AI Instructions (During Autonomous Implementation)

- Always reference the release specification; do not change code outside its scope
- If the specification is ambiguous, ask the human. For everything else, proceed autonomously
- Include development insights in the PR description (potential issues discovered, unexpected behaviors, technical constraints, design rationale)
- After implementation, run the full review kata: checks → self-evaluation → independent review → fix → commit

## Development Insights

During implementation, the AI may discover:

- Latent issues or risks in existing code
- Behaviors that differ from expectations
- Technical constraints that affect future work
- Performance or security observations
- Rationale for design choices made

These insights are recorded in the PR description under a dedicated section, making implicit knowledge explicit for reviewers and future developers.

## Relationship with VDD

RDD is the **execution engine**. [VDD](./VDD.md) is the **upstream input layer**.

VDD defines direction and decisions. RDD receives them, translates them into release specifications, and executes the full cycle from implementation through review to merge.

## Further Reading

- [VDD Specification](./VDD.md) — Vision-Driven Development
- [Branch Strategy](./branch-strategy.md) — 3-layer branch structure
- [QA Layers](./qa-layers.md) — 3-layer quality assurance model
- [Enforcement Levels](./enforcement-levels.md) — How rules are technically enforced
- [Cloud Execution](./cloud-execution.md) — Headless VPS execution
