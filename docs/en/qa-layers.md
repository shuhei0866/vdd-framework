# QA Layers — 3-Layer Quality Assurance Model

## Overview

Quality assurance in the VDD Framework follows a 3-layer model. Each layer catches different types of issues, and no single layer is sufficient on its own. The layers are designed to be complementary, not redundant.

## The 3 Layers

| Layer | Executor | Focus | Catches |
|-------|----------|-------|---------|
| **Layer 1**: Automated Verification | AI | Code correctness | Bugs, type errors, lint violations, test failures, code quality issues |
| **Layer 2**: Visual & Behavioral Check | AI + Human | User experience | UI inconsistencies, interaction problems, visual regressions |
| **Layer 3**: Exploratory QA | Human | "Does this feel right?" | Usability issues, edge cases, unintended behaviors, "something feels off" |

## Layer 1: Automated Verification

**Executor**: AI agent (autonomous)

Layer 1 is fully automated and runs as part of every release cycle. It is the foundation — if Layer 1 fails, nothing else proceeds.

### Components

| Check | Tool | Purpose |
|-------|------|---------|
| Type checking | `{{TYPE_CHECK_COMMAND}}` | Catches type errors and interface mismatches |
| Linting | `{{LINT_COMMAND}}` | Enforces code quality and conventions |
| Unit tests | `{{TEST_COMMAND}}` | Verifies individual component behavior |
| E2E tests | `{{E2E_COMMAND}}` (if available) | Verifies full user flows |
| Self-evaluation | Release readiness check | AI assesses its own work against the release spec |
| Independent AI review | Code review skill | Separate AI agent reviews from fresh context |
| External AI review | External review tool | Different AI model provides alternative perspective |

### Execution Order

```
1. Run project checks (type + lint + tests)    ← must pass
2. Self-evaluation (release readiness)          ← must pass
3. Independent AI review                        ← fix any issues found
4. External AI review (optional)                ← fix any issues found
5. Re-run checks if changes were made
```

### What Layer 1 Catches

- Compilation and type errors
- Lint rule violations
- Test regressions
- Code quality issues (complexity, duplication, security)
- Scope violations (changes outside the release spec)
- Missing tests for new behavior
- Inconsistencies between implementation and spec

### What Layer 1 Misses

- Visual appearance and layout issues
- "Feels wrong" usability problems
- Business logic that is technically correct but practically wrong
- Edge cases that no test covers
- Integration issues only visible in a running application

## Layer 2: Visual & Behavioral Check

**Executor**: AI agent + Human (using preview environment)

Layer 2 bridges the gap between automated checks and human judgment. It focuses on what the change *looks and feels like* in a running application.

### Components

| Check | Executor | Purpose |
|-------|----------|---------|
| Screenshot evaluation | AI | Compare before/after visual states |
| Preview operation | AI + Human | Interact with the deployed preview |
| Interaction testing | AI | Verify user flows work as expected |
| Accessibility check | AI | Basic accessibility verification |

### How It Works

```
develop branch merged → Preview environment deployed
    ↓
AI takes screenshots, evaluates visual consistency
    ↓
AI interacts with preview, verifies user flows
    ↓
Human checks preview (optional at this layer)
    ↓
Issues found → fix → re-deploy → re-check
```

### What Layer 2 Catches

- UI elements misaligned or missing
- Colors, fonts, spacing that don't match the design system
- Broken interactions (buttons that don't work, forms that don't submit)
- Responsive layout issues
- Visual regressions

### What Layer 2 Misses

- Subtle usability problems
- "I expected it to work differently" issues
- Edge cases in unusual user scenarios
- Performance problems under real conditions

## Layer 3: Exploratory QA

**Executor**: Human

Layer 3 is exclusively human. No AI can replace the "something feels off" instinct that comes from actually using the product. This is the final quality gate before production promotion.

### What the Human Does

- **Uses the preview environment directly** — clicks, types, navigates as a real user would
- **Follows happy paths** — verifies that the main feature works as described
- **Explores edge cases** — what happens with unusual input, unexpected sequences
- **Trusts gut feeling** — if something feels wrong, it probably is
- **Provides feedback** — approve for production or request changes

### When Layer 3 Happens

Layer 3 occurs at the **feedback meeting**, after the change has been merged to the integration branch and deployed to the preview environment.

```
release/* → develop (AI merge)
    ↓
Preview environment available
    ↓
Feedback meeting: Human performs Layer 3 QA
    ↓
approve → develop → main (production promotion)
   or
reject → AI fixes → back to Layer 1
```

### What Layer 3 Catches

- "This doesn't feel intuitive"
- "The user wouldn't know to click here"
- "This is technically correct but practically confusing"
- "I found a scenario nobody tested"
- "The performance is noticeably slow for this action"

### What Only Humans Can Judge

- Product-market fit
- "Is this what we actually need?"
- Subjective quality ("good enough" vs "not yet")
- Trust and safety edge cases
- The overall *experience*, not just functionality

## Layer Interaction

The layers form a pipeline where each subsequent layer builds on the previous one's passing:

```
Layer 1 (automated)     Must pass before Layer 2
    ↓
Layer 2 (visual/behavioral)    Must pass before Layer 3
    ↓
Layer 3 (exploratory)   Must pass before production promotion
```

### Feedback Loops

Issues found at any layer flow back to implementation:

```
Layer 3 issue found → AI fixes → Layer 1 re-run → Layer 2 re-check → Layer 3 re-verify
Layer 2 issue found → AI fixes → Layer 1 re-run → Layer 2 re-check
Layer 1 issue found → AI fixes → Layer 1 re-run
```

## VDD Iteration Loop

AI autonomously iterates through Layers 1 and 2 until both pass:

```
Implementation (TDD) → Layer 1 checks → Layer 2 visual check
        ↑                                        |
        └────── Fix if issues found ◄────────────┘

All passing → merge to develop → notify human for Layer 3
```

The AI evaluates each quality dimension (code quality, user experience, feature completeness) and focuses improvement on the weakest area. The threshold for "sufficient" is developed empirically through operation.

## Relationship to Other Framework Components

| Component | QA Connection |
|-----------|--------------|
| TDD | Foundation of Layer 1 — tests must exist before implementation |
| Code review | Part of Layer 1 — independent perspective on code quality |
| Release spec | Layer 1 checks scope adherence; Layer 3 checks behavior against spec |
| Branch strategy | Layer 3 QA happens on `develop` preview before `main` promotion |
| Decision authority | Layer 3 QA verdict is a human decision (see [Decision Authority Matrix](./decision-authority-matrix.md)) |

## Further Reading

- [RDD Specification](./RDD.md) — Release phases including review
- [Decision Authority Matrix](./decision-authority-matrix.md) — Who makes the QA decision
- [Branch Strategy](./branch-strategy.md) — Where each layer operates
- [Debate Partner](./debate-partner.md) — Complementary to QA: verifying decision correctness
