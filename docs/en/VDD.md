# VDD — Vision-Driven Development

## Overview

Vision-Driven Development (VDD) is a methodology for continuously updating a project's vision through daily decisions, then feeding that vision into autonomous development cycles. VDD answers the question: **"What should we build and why?"**

VDD is the strategic layer of the framework. It pairs with [RDD](./RDD.md) (Release-Driven Development), which handles execution. Together, they form a complete AI-autonomous development pipeline.

## Core Idea

Daily decisions shape the vision. The vision shapes what gets built. What gets built generates feedback. Feedback shapes tomorrow's decisions.

```
Decisions → Vision → Release Specs → Implementation → Feedback → Decisions
```

## Guiding Principles

1. **Natural language first**: Operate using plain text documents, not rigid schemas
2. **Fixed locations, flexible content**: Reduce ambiguity by keeping artifacts in consistent, well-known locations
3. **Minimal structure**: Avoid over-schematizing. Use only the structure needed to prevent misinterpretation

## Key Artifacts

### Vision Document

A living document (`VISION.md`) that captures the project's current direction. It contains:

- **Current direction**: Where the project is heading
- **Core values**: What the project prioritizes
- **Not doing now**: What is explicitly deferred (prevents scope creep)
- **Quality bar**: The minimum standard for releases

The vision document is **not** updated daily. It changes only when direction, values, or quality standards actually shift.

### Decision Log

A chronological record of decisions (`DECISIONS.md`). Each entry includes:

- **Decision ID**: Date-based sequential numbering (e.g., `D-20260207-01`)
- **Context**: Why this decision was made (the most important field)
- **Impact and priority**
- **Status**: `active`, `dropped`, or `superseded`

When a new decision contradicts an older one, the new entry uses `supersedes: <decision_id>` to create an explicit link. The old entry is marked `superseded`.

### Daily Subjective Score

A daily record (`DAILY_SCORE.md`) where the human rates the day on a 1-5 scale:

- **Score**: 1 (terrible) to 5 (excellent)
- **Evaluation axis**: "Did I feel like we shipped something good, quickly?"
- **Timing**: Recorded at the end of the day's final meeting

This is intentionally subjective. The goal is to track *felt momentum*, not objective metrics.

## Operating Loop

```
1. Review previous learnings (start of feedback meeting)
2. Hold decision-making meeting (feedback meeting / review meeting)
3. Record decisions in Decision Log
4. Update Vision Document (if direction changed)
5. Record Daily Subjective Score
6. Reflect decisions into Release Specifications
7. Execute via RDD (implement → review → QA)
8. Record any VDD process learnings for next cycle
```

### Step 1: Review Previous Learnings

At the start of each feedback meeting, review the learnings file and recent decision log entries. Verify whether previous feedback actually resulted in behavioral changes. This prevents the same issues from recurring.

### Step 8: Process Reflection

If the VDD process itself can be improved, record the insight in `process/VDD-learnings.md`. In the next feedback meeting, review accumulated learnings and decide whether VDD.md itself needs updating.

### VDD Learnings File

The learnings file (`process/VDD-learnings.md`) serves as a **supplementary document** for the operating loop — distinct from the main artifacts (Vision / Decisions / Daily Score).

- **Role**: A buffer before updating VDD.md. Accumulates observations that may or may not warrant changes to the process specification
- **When to write**: Step 8 of the operating loop (process reflection)
- **When to review**: Step 1 of the operating loop (review previous learnings)
- **Recommended format**: "Context / What happened / Why / What to do next" (not enforced)
- **Promotion to VDD.md**: Decided during feedback meetings based on accumulated evidence

## Meeting Cadence

- **Default**: Two fixed meetings per day (feedback meeting + PR review meeting)
- **Time allocation within meetings**: Not fixed — optimize per session

### Roles in Meetings

| Role | Responsibility |
|------|---------------|
| AI | Proposes meeting agenda and decision candidates |
| Human | Makes final judgment on each candidate (approve / reject / conditional) |

### Approval Format

| Verdict | Meaning |
|---------|---------|
| `approve` | Decision accepted. Proceed with implementation |
| `reject` | Decision rejected. Do not implement |
| `conditional` | Accepted with conditions. Implementation blocked until conditions are met |

- `conditional` conditions are described in free text
- Condition completion is judged operationally (not automated)

## Artifact Update Rules

| Artifact | Update Frequency | Trigger |
|----------|-----------------|---------|
| Vision Document | As needed | Direction, values, or quality bar changes |
| Decision Log | Every meeting | Any decision made in the meeting |
| Daily Score | Daily | End of final daily meeting |

## Decision Conflict Resolution

When a new decision contradicts an existing one:

1. The new entry includes `supersedes: <old_decision_id>`
2. The old entry's status is changed to `superseded`
3. The chain of supersession is preserved for traceability

## Release Spec Checklist

Before merging a `release/*` branch, the following 8 items must pass:

| # | Check | Description |
|---|-------|-------------|
| 1 | Vision alignment | Release does not contradict VISION.md |
| 2 | Decision alignment | Release implements approved decisions |
| 3 | Conditional resolution | All `conditional` items are resolved |
| 4 | Core flow non-breaking | Primary user journeys are not disrupted |
| 5 | Risk disclosure | Known risks are explicitly documented |
| 6 | Rollback capability | Release can be reverted if needed |
| 7 | Review passed | Independent review completed |
| 8 | Scope adherence | No changes outside release spec scope |

## Debate Partner

After creating a release spec draft, an external AI conducts a debate-style dialogue to verify vision alignment. See [Debate Partner](./debate-partner.md) for full details.

### Why External

The debate partner is intentionally placed *outside* the project's active context:

- **Surfaces hidden assumptions**: Explaining to someone without full context forces articulation of what was taken for granted
- **Forces plain-language articulation**: Technical jargon and internal references don't work, so the "why" must be re-stated clearly
- **Rubber-duck for decisions**: Code review verifies *code correctness*. Debate verifies *decision correctness*. These are complementary, not redundant

### Context Boundary

| The partner CAN access | The partner DOES NOT have |
|------------------------|--------------------------|
| Repository codebase (structure, existing code) | Active session context (design dialogue history, in-progress experiments) |

What is provided: the release spec (and optionally VISION.md).

## Decision Authority Matrix

See [Decision Authority Matrix](./decision-authority-matrix.md) for the full breakdown of who decides what, and under what circumstances AI can act autonomously vs. requiring human approval.

## Guardrails

- Implementation that contradicts the vision must document the reason
- Decisions without traceable rationale are not prioritized
- When multiple interpretations exist, default to human confirmation
- High production-risk changes pause autonomous implementation
- High user-impact changes require confirmation
- Difficult-to-rollback changes require confirmation
- Vision-alignment doubts require confirmation

## Success Metrics

- **Primary metric**: Daily Subjective Score (1-5)
- **Evaluation axis**: "Did we ship something good, quickly?"
- **Recorded**: End of each day's final meeting
- **Purpose**: Track felt momentum, not objective output

## Branch Strategy

VDD uses a 3-layer branch strategy to safely operate autonomous development cycles. See [Branch Strategy](./branch-strategy.md) for details.

## QA Model

Quality assurance follows a 3-layer model: automated tests, AI review, and human exploratory QA. See [QA Layers](./qa-layers.md) for details.

## Autonomous Execution

Phases 2-3 (implementation through merge) can run headlessly on a cloud server. See [Cloud Execution](./cloud-execution.md) for the setup guide.

## Relationship with RDD

VDD is the **"what and why"** layer. [RDD](./RDD.md) is the **"how to deliver"** layer.

VDD produces direction and decisions. RDD consumes them as inputs, translates them into release specifications, and executes autonomously. Separating strategy from execution ensures that vision updates and implementation stability do not interfere with each other.
