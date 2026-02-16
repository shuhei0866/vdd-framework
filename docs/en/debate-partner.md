# Debate Partner — External AI for Decision Verification

## Overview

The debate partner is an external AI that conducts a debate-style dialogue to verify **vision alignment** before implementation begins. It complements code review (which verifies *code correctness*) by verifying *decision correctness*.

This is not another reviewer. It is a thinking partner that forces you to articulate *why* you're building something, not just *how*.

## Why External

The debate partner is intentionally placed **outside** the project's active development context. This separation is the key design decision.

### What Externalization Achieves

| Effect | Mechanism |
|--------|-----------|
| **Surfaces hidden assumptions** | Explaining to someone without full context forces you to make implicit assumptions explicit |
| **Forces plain-language articulation** | Technical jargon and internal references don't work, so you must re-state the "why" clearly |
| **Rubber-duck for decisions** | The act of explaining a decision to an outsider often reveals its weaknesses |

### The Complementary Relationship

```
Code Review (/review-now, etc.)     Debate Partner
─────────────────────────────       ──────────────────────
Verifies code correctness           Verifies decision correctness
"Is this implemented right?"        "Should we build this at all?"
Has full code context               Has limited context (by design)
Technical depth                     Strategic breadth
```

These two are complementary, not redundant. Combining them into one step would weaken both.

## Context Boundary

The debate partner has a deliberately constrained view of the project:

| Can Access | Does Not Have |
|------------|--------------|
| Repository codebase (structure, existing implementation) | Active session context (design dialogue history, in-progress experiments) |
| Release specification | Real-time implementation decisions |
| Vision document (if provided) | The "why behind the why" that emerged in conversation |

**What you provide**: The release specification, and optionally the vision document. Nothing more.

This boundary ensures the partner stays at the strategic level — "why are we building this?" — rather than getting pulled into implementation details.

## Principles

### 1. Take a Position

The partner must take a clear stance — for or against. Agreement without friction produces no insight.

**Good**: "I disagree with this approach because it contradicts your stated priority of simplicity."
**Bad**: "This seems reasonable. Have you considered alternatives?"

### 2. Ideas That Survive Attacks Are Stronger

The goal is not to find the "right answer" through discussion. It is to **stress-test the decision** until only the strongest reasoning remains.

### 3. Record Conclusions, Not Transcripts

The full debate conversation lives in whatever channel was used. Only the conclusions and the fact that a debate occurred are recorded in the decision log.

### 4. The Partner is a Mirror, Not a Judge

The debate partner helps you think, but does not make decisions. **All final decisions are made by the human** at the feedback meeting.

## Operating Flow

The debate is embedded in Phase 1 (Design Dialogue), after the release spec draft is ready but before human approval:

```
Phase 1: Design Dialogue (Human + AI)
    ↓
    AI: Creates release spec draft
    ↓
    AI → Debate Partner: Sends key questions + release spec
    ↓
    Partner: Critiques from vision-alignment perspective
    ↓
    AI ↔ Partner: Multiple rounds of argument (as needed)
    ↓
    AI: Summarizes debate results
    ↓
Feedback Meeting: Release spec + debate results presented to human
    ↓
Human: approve / reject / conditional
    ↓
Phase 2: Implementation
```

### Trigger

The debate is triggered when a release spec draft is complete — at the boundary between Phase 1 and Phase 2.

### Waiting Behavior

The implementing AI waits for the debate to conclude (blocking). If independent tasks exist, they can proceed in parallel via separate agents.

## Question Design

The quality of the debate depends entirely on the quality of the questions. Good questions don't seek answers — they force the explainer to confront contradictions and ambiguities in their own thinking.

### Design Principles

1. **Avoid Yes/No questions**: Force the respondent to take a position
2. **Ask about choices, not correctness**: Tradeoffs are more revealing than right/wrong
3. **Assume the counterargument**: Frame questions expecting pushback

### Phase-Specific Question Templates

#### Phase 1: Design Dialogue (Highest Impact)

Direction changes are cheapest at this stage. This is where debate has the most value.

| Question | What It Surfaces |
|----------|-----------------|
| "Who uses this, and what do they do today without it?" | Resolution of the user persona |
| "Could this problem be solved without building anything?" | Implementation bias |
| "Will this still be in use 3 months from now?" | Temporary excitement vs. lasting value |
| "If this feature succeeds, what changes?" | Goal clarity |
| "Does this conflict with 'not doing now' in the vision?" | Vision alignment |

#### Phase 3: Pre-Merge Review

| Question | What It Surfaces |
|----------|-----------------|
| "Explain this change in one sentence." | Scope appropriateness |
| "Will users notice? Will they be happy?" | Experience impact |
| "What happens if we don't ship this?" | True necessity |

#### Daily Feedback Meeting

| Question | What It Surfaces |
|----------|-----------------|
| "What was the hardest decision today?" | Articulation of uncertainty |
| "How would you explain the current direction to a stranger?" | Vision internalization |

### Anti-Patterns

| Anti-Pattern | Why It Fails |
|-------------|--------------|
| "Is this design okay?" | Invites agreement, not reflection |
| "What should the API parameter types be?" | That's a code review question, not a debate question |
| "Is user experience important?" | Nobody disagrees, so no useful discussion happens |

## Recording Results

In the decision log:

```markdown
## D-YYYYMMDD-NN: <Decision Title>
- debate: <channel> YYYY-MM-DD
- summary: <Key arguments raised and conclusions reached>
- decision: <Human's final judgment>
```

The full transcript lives in the conversation channel (chat platform, session log, etc.). Only the structured summary goes into the decision log.

## Satisfaction Threshold

The debate partner does not decide outcomes. The human does.

| Verdict | Criteria |
|---------|---------|
| **Human Go** | Debate results reviewed; vision alignment is satisfactory → `approve` |
| **Human Stop** | Concerns raised in debate are unresolved → `reject` or `conditional` |

The partner is a **mirror**, not an **arbiter**.

## Implementation

### Interface

The debate can happen over any text-based channel. The framework does not mandate a specific platform. Requirements:

1. The implementing AI can send messages to the partner
2. The partner can respond
3. Multiple rounds of exchange are possible
4. The conversation is preserved for reference

### Default Implementation

For projects using Claude Code as the primary AI:

- **Channel**: Any chat platform with API access (Discord, Slack, etc.)
- **Partner**: A different AI model or service (e.g., Gemini, GPT, a separate Claude instance)
- **Integration**: The implementing AI sends and receives messages via the platform's API

The key requirement is that the partner uses a **different model or context** than the implementing AI, to ensure genuinely different perspectives.

## Multi-AI Review: The Broader Concept

The debate partner is one instance of a broader principle: **using multiple AI perspectives to catch different types of issues**.

| Perspective | Focus | Example |
|------------|-------|---------|
| Implementing AI (self-review) | "Did I implement the spec correctly?" | Release readiness check |
| Independent AI reviewer (same model) | "Is the code quality acceptable?" | Code review from fresh context |
| External AI reviewer (different model) | "What did the other reviewers miss?" | Different model, different blind spots |
| Debate partner (external, limited context) | "Should this be built at all?" | Vision alignment verification |

Each perspective catches different classes of issues. No single perspective is sufficient. See [QA Layers](./qa-layers.md) for how these perspectives integrate into the quality assurance model.

## Evolution

The question templates, channel setup, and debate effectiveness should be refined through practice. As you conduct more debates, you'll discover:

- Which questions produce the most useful insights
- What level of detail to include in the release spec for the partner
- How many rounds of debate are typically needed
- When debate is most valuable (not every release needs it)

Record these learnings and update this document accordingly.

## Further Reading

- [VDD Specification](./VDD.md) — Vision-Driven Development, which the debate partner supports
- [QA Layers](./qa-layers.md) — How multi-perspective review fits into QA
- [Decision Authority Matrix](./decision-authority-matrix.md) — The partner advises; humans decide
- [Philosophy](./philosophy.md) — "Multi-perspective review over single-point review"
