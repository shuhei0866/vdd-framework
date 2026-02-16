# Branch Strategy — 3-Layer Branch Structure

## Overview

The VDD Framework uses a simplified GitFlow branch strategy with three layers. Each layer serves a distinct purpose and has clear rules about what can merge into it and who can trigger the merge.

## The 3 Layers

```
main (production)          ← Human triggers promotion (feedback meeting)
  ↑
develop (integration)      ← AI merges after independent approval, preview environment
  ↑
release/* (work branches)  ← AI implements in isolated worktrees via TDD
```

| Branch | Lifetime | Purpose | Who Merges Into It |
|--------|----------|---------|-------------------|
| `main` | Permanent | Production. What users see | Human (via promotion) |
| `develop` | Permanent | Integration and preview. Where releases land first | AI (after approval) |
| `release/*` | Temporary | Isolated work on a single release | N/A (merges *from* here) |

## Branch Rules

### `main` (Production)

- **Always deployable**: Every commit on `main` should be production-ready
- **Merge source**: Only `develop` merges into `main`
- **Merge trigger**: Human decides at the feedback meeting, after Layer 3 QA passes
- **Direct commits**: Prohibited (except emergency hotfixes, which are then synced to `develop`)
- **Force push**: Prohibited (L5 hook enforced)

### `develop` (Integration)

- **Permanent branch**: Never deleted (L5 hook enforced)
- **Preview environment**: Optionally deployed for human QA
- **Merge source**: `release/*` branches merge into `develop`
- **Merge trigger**: AI implementing agent, after independent approver's `approve`
- **Post-promotion sync**: After `develop → main`, rebase `develop` onto `main` to stay in sync

### `release/*` (Work Branches)

- **One release, one branch**: Each release specification gets its own `release/*` branch
- **Worktree isolated**: Always worked on in a git worktree, never in the main working tree
- **Short-lived**: Created at the start of Phase 2, deleted after merge to `develop`
- **Direct merge to `main` prohibited**: Must go through `develop` first (L5 hook enforced)

## Merge Flow

### Normal Release Flow

```
1. Create release branch: release/feature-name
2. Create worktree for the branch
3. Implement with TDD in the worktree
4. Run checks + self-review + independent review
5. Create PR: release/feature-name → develop
6. Independent approver approves
7. Implementing agent confirms approval, merges (squash)
8. Human performs Layer 3 QA on develop preview
9. Human promotes: develop → main
10. Sync: rebase develop onto main
```

### Hotfix Flow

For urgent production fixes that cannot wait for the normal flow:

```
1. Create hotfix branch from main
2. Fix + test in worktree
3. PR to main (exceptional — requires human approval)
4. After merge to main, sync develop: merge main into develop
```

### Post-Promotion Sync

After promoting `develop → main`:

```bash
# On develop branch
git rebase main
# This keeps develop in sync with main
```

## Enforcement

| Rule | Enforcement Level | Mechanism |
|------|-------------------|-----------|
| No direct edits in main worktree | L5 (deny) | `worktree-guard.sh` blocks Write/Edit |
| No `release/*` → `main` direct merge | L5 (deny) | `commit-guard.sh` blocks the merge |
| No `develop` branch deletion | L5 (deny) | `commit-guard.sh` blocks deletion |
| No force push to `main` | L5 (deny) | `commit-guard.sh` blocks `--force` |
| No `--no-verify` | L5 (deny) | `commit-guard.sh` blocks the flag |
| No branch switching in main worktree | L5 (deny) | `commit-guard.sh` blocks `checkout`/`switch` |

See [Enforcement Levels](./enforcement-levels.md) for details on each enforcement mechanism.

## Parallel Work

Multiple `release/*` branches can exist simultaneously:

```
develop
  ↑
  ├── release/feature-a  (worktree A)
  ├── release/feature-b  (worktree B)
  └── release/feature-c  (worktree C)
```

Rules for parallel work:
1. **No file conflicts**: Each release should modify different files/directories
2. **Shared resource changes are serialized**: Database migrations, shared type definitions, and common configuration changes should be assigned to a single release
3. **Dependencies use release tree notation**: If release B depends on release A, this is expressed using `blockedBy` in the release tree

## Worktree Isolation

Every `release/*` branch is worked on in a dedicated git worktree:

```
project/                          ← Main worktree (READ-ONLY for AI)
project-worktrees/
├── release-feature-a/            ← Worktree for release/feature-a
├── release-feature-b/            ← Worktree for release/feature-b
└── release-feature-c/            ← Worktree for release/feature-c
```

Why worktrees instead of just branches:
- **No branch switching needed**: Each worktree is its own directory with its own checkout
- **Parallel work is safe**: Multiple agents can work in different worktrees simultaneously
- **Main worktree is protected**: The main directory never enters a dirty state
- **Uncommitted work is safe**: Nothing in the main worktree is touched

See [Philosophy](./philosophy.md) for the rationale behind worktree isolation.

## Relationship to QA Layers

| QA Layer | Where It Happens |
|----------|-----------------|
| Layer 1 (automated) | On the `release/*` branch, in the worktree |
| Layer 2 (visual/behavioral) | On the `develop` preview environment |
| Layer 3 (exploratory) | On the `develop` preview environment, at the feedback meeting |
| Production promotion | `develop` → `main`, after Layer 3 passes |

See [QA Layers](./qa-layers.md) for the full quality assurance model.

## Further Reading

- [RDD Specification](./RDD.md) — Release phases that use this branch strategy
- [Enforcement Levels](./enforcement-levels.md) — How branch rules are technically enforced
- [QA Layers](./qa-layers.md) — Quality assurance at each branch layer
- [Philosophy](./philosophy.md) — Why worktree isolation matters
- [Cloud Execution](./cloud-execution.md) — Running parallel releases on a VPS
