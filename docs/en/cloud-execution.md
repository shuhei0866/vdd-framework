# Cloud Execution — Headless VPS Execution

## Overview

Cloud execution enables VDD/RDD Phase 2-3 (autonomous implementation through merge) to run on a remote server, independent of your local machine. This means you can close your laptop after the design dialogue and let the AI continue working.

## Why Cloud Execution

The core problem: **AI autonomous execution is interrupted when your local machine sleeps.**

Design dialogues (Phase 0-1) are interactive — they require human participation. Implementation (Phase 2-3) is autonomous — the AI works independently. Cloud execution separates these two modes:

| Phase | Location | Mode |
|-------|----------|------|
| Phase 0-1: Requirements + Design | Local machine | Interactive (human + AI) |
| Phase 2-3: Implementation + Review | Cloud VPS | Headless (AI only) |
| Phase 4: QA | Anywhere | Human reviews preview |

## Infrastructure Requirements

| Component | Requirement | Purpose |
|-----------|-------------|---------|
| VPS | 4+ vCPU, 16+ GB RAM recommended | Run AI agent + build tools |
| OS | Linux (Ubuntu 22.04+ recommended) | Host environment |
| Node.js | 22+ | Build tooling |
| tmux | 3.0+ | Session persistence across disconnects |
| Claude Code CLI | Latest | AI agent execution |
| Git | 2.20+ | Worktree support |
| SSH access | IAP tunnel or direct SSH | Secure access |

## Setup

### 1. Provision the VPS

Use any cloud provider. Example with Google Cloud:

```bash
# Create instance
gcloud compute instances create {{INSTANCE_NAME}} \
  --zone={{ZONE}} \
  --machine-type=e2-standard-4 \
  --image-family=ubuntu-2404-lts \
  --image-project=ubuntu-os-cloud

# Start/stop as needed
gcloud compute instances start {{INSTANCE_NAME}} --zone={{ZONE}}
gcloud compute instances stop {{INSTANCE_NAME}} --zone={{ZONE}}
```

### 2. Install Dependencies

On the VPS:

```bash
# Node.js
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# Package manager (pnpm, npm, yarn — whatever your project uses)
npm install -g {{PACKAGE_MANAGER}}

# Claude Code CLI
sudo npm install -g @anthropic-ai/claude-code

# tmux
sudo apt-get install -y tmux

# Authenticate Claude Code
claude login
```

### 3. Clone and Configure

```bash
# Clone your repository
git clone {{REPO_URL}} ~/{{PROJECT_NAME}}
cd ~/{{PROJECT_NAME}}

# Install dependencies
{{INSTALL_COMMAND}}

# Run framework setup (if provided)
bash .claude/cloud/setup.sh
```

### 4. Configure Environment Variables

Create `~/.claude/.env` with required secrets:

```bash
# Notification webhook (optional)
WEBHOOK_URL={{NOTIFICATION_WEBHOOK_URL}}

# Any project-specific secrets
# (Never commit these to the repository)
```

## Workflow

### Starting a Headless Session

```bash
# 1. SSH into VPS
ssh {{VPS_CONNECTION}}

# 2. Create tmux session
tmux new-session -s release-{{NAME}}

# 3. Update repository
cd ~/{{PROJECT_NAME}} && git pull origin develop

# 4. Launch Claude Code headlessly
claude -p "
Implement according to release spec at {{RELEASE_SPECS_DIR}}/{{NAME}}.md.

Steps:
1. Create worktree and release/{{NAME}} branch
2. Implement with TDD (test-first)
3. Run checks (type check + lint + tests)
4. Self-evaluation
5. Independent review
6. Fix any issues
7. Create PR targeting develop
8. Wait for approval
9. Merge after approval confirmed
" --allowedTools "Bash,Read,Write,Edit,Glob,Grep"

# 5. Detach tmux (Ctrl+B then D)
# Now you can close your laptop
```

### Checking Progress

```bash
# SSH back in and reattach
ssh {{VPS_CONNECTION}}
tmux attach -t release-{{NAME}}
```

### Parallel Execution

For releases that can run in parallel (no file conflicts):

```bash
# Session A
tmux new-session -d -s release-a
tmux send-keys -t release-a "cd ~/{{PROJECT_NAME}} && claude -p '...' --allowedTools '...'" Enter

# Session B
tmux new-session -d -s release-b
tmux send-keys -t release-b "cd ~/{{PROJECT_NAME}} && claude -p '...' --allowedTools '...'" Enter

# Monitor both
tmux list-sessions
tmux attach -t release-a  # Check session A
# Ctrl+B D to detach, then:
tmux attach -t release-b  # Check session B
```

**Important**: Ensure parallel releases don't modify the same files. Each release uses its own worktree.

## Daily Operation Flow

```
[Local] Design dialogue (Phase 0-1)
    |
    ├── Create release specification
    ├── git push
    |
    ▼
[VPS] Autonomous implementation (Phase 2-3)
    |
    ├── Claude Code headless execution
    ├── TDD → review → PR creation
    ├── Notify (webhook) when done
    ├── Wait for approval
    ├── Merge to develop after approval
    |
    ▼
[Approver] Independent review
    |
    ├── Review the PR
    ├── Approve (or request changes)
    |
    ▼
[Local/Mobile] Verification
    |
    ├── Check PR and develop preview
    ├── Feedback meeting: decide on develop → main promotion
```

## Notifications

Configure a notification webhook so you know when the AI finishes:

### Webhook Notification

```bash
# Example: notify on session completion
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"Release {{NAME}} implementation complete. PR created.\"}"
```

This can be set up as a Claude Code Stop hook to fire automatically when the session ends.

### Communication Channels

| Channel | Direction | Purpose |
|---------|-----------|---------|
| Webhook (Stop hook) | VPS → Team | Session completion notification |
| Webhook (autonomous) | VPS → Team | Intermediate status (PR created, errors) |
| Chat integration | Bidirectional | Receive instructions, send updates |
| GitHub PR | Bidirectional | Code review and approval |

## Maintenance

### Repository Updates

Keep the VPS repository in sync:

```bash
cd ~/{{PROJECT_NAME}} && git pull origin develop
```

### Claude Code Updates

```bash
sudo npm install -g @anthropic-ai/claude-code
```

### Authentication Refresh

If Claude Code's token expires:

```bash
claude login
# Follow the URL to re-authenticate
```

### Disk Management

Worktrees accumulate over time. Clean up regularly:

```bash
git worktree list          # See all worktrees
git worktree remove <path> # Remove completed ones
```

## Cost Management

- **Only run the VPS when needed**: Stop the instance when no releases are in progress
- **Stopped instances** only incur disk storage costs (minimal)
- **Running instances** cost per hour based on machine type

```bash
# Stop when done
gcloud compute instances stop {{INSTANCE_NAME}} --zone={{ZONE}}

# Check status
gcloud compute instances list --filter="name={{INSTANCE_NAME}}"
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| SSH connection refused | Wait a few seconds after instance start. Use IAP tunnel if direct SSH is blocked |
| Claude Code auth expired | Run `claude login` on the VPS |
| Build fails | Check Node.js version (`node --version`). Ensure 22+ |
| tmux session disappeared | VPS may have restarted. Check with `tmux list-sessions` |
| Disk full | `df -h /` to check. Remove old worktrees with `git worktree remove` |
| Cloud provider auth expired | Re-authenticate with your cloud provider CLI |

## Security Considerations

- **Never store secrets in the repository**. Use environment variables on the VPS
- **Use IAP tunneling or VPN** instead of exposing SSH to the internet
- **Restrict VPS network access** to only necessary services
- **Rotate credentials regularly**, especially for AI service tokens
- **Stop instances** when not in use (cost and security)

## Further Reading

- [RDD Specification](./RDD.md) — The release phases that cloud execution automates
- [Branch Strategy](./branch-strategy.md) — How worktrees and branches work in parallel
- [Adoption Levels](./adoption-levels.md) — Cloud execution is part of Level 5 (Full Autonomous)
- [Philosophy](./philosophy.md) — "Maximum autonomy within enforced boundaries"
