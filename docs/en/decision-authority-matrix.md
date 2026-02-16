# Decision Authority Matrix

## Overview

The Decision Authority Matrix defines **who decides what** in a VDD/RDD project. It draws a clear boundary between human judgment and AI autonomy, ensuring that strategic decisions remain with humans while execution decisions are delegated to AI.

This matrix is a core artifact of VDD. Without it, the boundary between "AI should ask" and "AI should just do it" is ambiguous — leading either to excessive confirmation requests (slow) or unauthorized autonomous actions (dangerous).

## The Matrix

| Decision Type | Decider | Criteria | Human Confirmation |
|--------------|---------|----------|-------------------|
| **Vision changes** | Human | Discussed and agreed in feedback meeting | Required |
| **Release specification creation** | Human | AI proposes, human approves | Required |
| **Design approach** | Human + AI | Design dialogue, debate partner feedback | Required |
| **Release splitting** | Human + AI | Agreed during design dialogue | Required |
| **`release/*` → `develop` merge** | AI (implementing agent) | After independent approver's `approve` | Not required |
| **`develop` → `main` promotion** | Human | Feedback meeting, Layer 3 QA passed | Required |
| **Implementation decisions (within spec)** | AI | Within release spec scope, tests pass | Not required |
| **Refactoring decisions** | AI | Within scope, tests pass | Not required |
| **Decision log updates** | Human | Decisions are recorded during meetings | Required |

## Principles

### 1. Separation of Approval and Merge

The approval and merge steps are performed by different actors:

```
Independent approver → approves the PR (quality/correctness check)
Implementing agent  → confirms approval, then executes merge
```

This separation ensures:
- The agent that wrote the code does not approve its own work
- The approver focuses on review quality without merge logistics
- The implementing agent confirms approval programmatically before merging

### 2. AI Does Not Preempt Human Judgment

For decisions requiring human confirmation, the AI:
- **Proposes** options with analysis and tradeoffs
- **Waits** for human verdict (`approve` / `reject` / `conditional`)
- **Does not** proceed with implementation until approval is received

This applies to: vision changes, release specifications, design approaches, and any decision not explicitly listed as AI-autonomous.

### 3. Default to Confirmation When Unclear

If a decision type is not listed in the matrix, the default is to ask the human. It is better to confirm unnecessarily than to make an unauthorized strategic decision.

## Decision Categories

### Fully Human Decisions

These decisions require human judgment and cannot be delegated to AI:

| Decision | Why Human-Only |
|----------|---------------|
| Vision direction | Core product strategy — requires business context AI doesn't have |
| Quality bar changes | Subjective judgment about "good enough" |
| Production promotion | Final accountability for what users experience |
| Process changes | Methodology evolution requires lived experience |

### Collaborative Decisions (Human + AI)

These decisions benefit from AI analysis but require human final approval:

| Decision | AI's Role | Human's Role |
|----------|-----------|-------------|
| Release specification | Proposes content, identifies risks | Approves scope and approach |
| Release splitting | Suggests tree structure, identifies dependencies | Approves the split |
| Design approach | Analyzes tradeoffs, proposes options | Chooses the approach |
| Architecture decisions | Provides technical analysis | Makes the call |

### Fully AI Decisions

These decisions are delegated to AI within defined boundaries:

| Decision | Boundary | Override Trigger |
|----------|----------|-----------------|
| Implementation details | Release spec scope | Spec ambiguity → ask human |
| Test strategy | Coverage of spec requirements | Untestable requirements → ask human |
| Refactoring | Tests still pass, within scope | Major restructuring → ask human |
| Code style | Project conventions | Conflicting conventions → ask human |
| Merge execution | After confirmed approval | Approval not confirmed → do not merge |

## Escalation Rules

AI must escalate to human confirmation when:

1. **Vision conflict**: The implementation contradicts `VISION.md`
2. **Scope ambiguity**: The release spec is unclear about whether something is in scope
3. **High production risk**: The change could break production if it goes wrong
4. **High user impact**: The change significantly affects user experience
5. **Difficult rollback**: The change is hard to revert (e.g., destructive migration)
6. **Multiple valid interpretations**: More than one reasonable implementation exists
7. **Unlisted decision type**: The decision doesn't fit any category in this matrix

## Conditional Approvals

When a human gives a `conditional` verdict:

1. The condition is recorded in free text in the decision log
2. Implementation is **blocked** until the condition is met
3. Condition completion is determined operationally (not automated)
4. Once the condition is met, the original approval applies

Example:
```
Decision: D-20260207-03
Verdict: conditional
Condition: "Only proceed if the migration is backward-compatible"
Status: active (condition not yet verified)
```

## Relationship to Enforcement Levels

The decision authority matrix is enforced at different levels:

| Rule | Enforcement |
|------|-------------|
| No merge without approval | L5 (can be implemented as a hook) |
| Review required on release branches | L4 (review-enforcement hook) |
| AI escalates on ambiguity | L2 (CLAUDE.md rule) |
| Design decisions need human approval | L2 (CLAUDE.md rule) |

See [Enforcement Levels](./enforcement-levels.md) for how each level works.

## Example Scenarios

### Scenario: AI discovers a better approach mid-implementation

The release spec says to use approach A, but the AI discovers approach B is significantly better.

- **If B is within spec scope**: AI can switch, document the rationale in the PR
- **If B changes the scope**: AI must ask the human before proceeding

### Scenario: Merge after approval

```
1. AI creates PR targeting develop
2. Independent approver reviews and approves
3. AI checks: gh pr view <number> --json reviewDecision → "APPROVED"
4. AI merges: gh pr merge --squash
```

The AI does not need human confirmation for step 4 — the approval in step 2 is sufficient.

### Scenario: Ambiguous specification

The spec says "add user settings page" but doesn't specify which settings to include.

- AI must **not** guess which settings to add
- AI asks the human: "The spec mentions a settings page but doesn't list specific settings. Which settings should be included?"

## Further Reading

- [VDD Specification](./VDD.md) — Vision-Driven Development including guardrails
- [Philosophy](./philosophy.md) — "Humans judge, AI executes"
- [Enforcement Levels](./enforcement-levels.md) — Technical enforcement of authority boundaries
- [QA Layers](./qa-layers.md) — Quality assurance responsibilities
