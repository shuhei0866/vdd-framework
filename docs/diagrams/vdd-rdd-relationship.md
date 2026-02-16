# VDD and RDD Relationship

## Overview

This diagram illustrates the relationship between VDD (Vision-Driven Development) as the strategic layer and RDD (Release-Driven Development) as the execution layer.

## Diagram

```mermaid
graph TB
    subgraph VDD ["Vision-Driven Development (Strategic Layer)"]
        V[VISION.md<br/>Current Direction<br/>Values<br/>Quality Bar<br/>'Not Doing' List]
        D[DECISIONS.md<br/>Decision Log<br/>Context & Rationale<br/>Status Tracking]
        DS[DAILY_SCORE.md<br/>Subjective Score 1-5<br/>Release Quality Feel]

        V --> D
        D --> DS
    end

    subgraph RDD ["Release-Driven Development (Execution Layer)"]
        P0[Phase 0: Requirements<br/>Human: What to Achieve]
        P1[Phase 1: Design Dialogue<br/>Human + AI: How to Implement]
        P2[Phase 2: Autonomous Implementation<br/>AI: TDD Cycle]
        P3[Phase 3: Self-Review<br/>AI: Multi-perspective Review]
        P4[Phase 4: Merge + QA<br/>AI Merge + Human QA]

        P0 --> P1
        P1 --> P2
        P2 --> P3
        P3 --> P4
    end

    VDD -->|Strategic Alignment| P1
    D -->|Decision Context| P1
    P4 -->|Feedback Loop| D
    P4 -->|Quality Feeling| DS

    classDef vddStyle fill:#e1f5ff,stroke:#0288d1,stroke-width:2px
    classDef rddStyle fill:#fff3e0,stroke:#f57c00,stroke-width:2px

    class V,D,DS vddStyle
    class P0,P1,P2,P3,P4 rddStyle
```

## Reading Guide

### Two Layers

- **VDD (Vision-Driven Development)**: Strategic layer that manages "what we aim for"
  - `VISION.md`: Current direction, values, quality bar, and 'not doing' list
  - `DECISIONS.md`: Decision log with context and rationale
  - `DAILY_SCORE.md`: Daily subjective score (1-5) on release quality feeling

- **RDD (Release-Driven Development)**: Execution layer that implements "how to deliver"
  - Phase 0: Requirements definition by human
  - Phase 1: Design dialogue between human and AI
  - Phase 2: Autonomous implementation by AI using TDD
  - Phase 3: Self-review by AI with multiple perspectives
  - Phase 4: Merge by AI and QA by human

### Key Connections

1. **Strategic Alignment**: VDD provides strategic context to RDD Phase 1 (Design Dialogue)
2. **Decision Context**: Decision log influences implementation approach
3. **Feedback Loop**: Merge results feed back into decision log
4. **Quality Feeling**: Daily score captures the feeling of "releasing good things quickly"

### Separation of Concerns

By separating VDD (strategy update) and RDD (implementation execution), the framework achieves both:
- Continuous refinement of strategic direction
- Stable and reliable implementation process
