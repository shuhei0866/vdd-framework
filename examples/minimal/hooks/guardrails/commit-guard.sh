#!/bin/bash
# commit-guard: PreToolUse (Bash) - 危険な git 操作をブロック [L5]
#
# メインワークツリーでの保護ブランチ (main/develop) への直接コミット、
# --no-verify によるフックスキップ、force push、ブランチ切り替え、
# release/* → main 直接マージ、develop ブランチ削除などを検出してブロックする。

set -uo pipefail

INPUT=$(cat)

# command を取得
if command -v jq &>/dev/null; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
  exit 0
fi

if [ -z "${COMMAND:-}" ]; then
  exit 0
fi

# git コマンド以外はスキップ
case "$COMMAND" in
  *git\ *)
    ;;
  *)
    exit 0
    ;;
esac

# --- チェック 0: メインワークツリーでの git commit (保護ブランチ直接コミット防止) ---
# 注意: PreToolUse フックはメインワークツリーの CWD で実行される。
# git -C <path> でワークツリーを指定するケースがあるため、-C パスを考慮して判定する。
if echo "$COMMAND" | grep -qE 'git\s+(-C\s+\S+\s+)?commit\b'; then
  # コマンドから -C パスを抽出（あれば）
  GIT_C_PATH=$(echo "$COMMAND" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^ ]+).*/\1/p')

  if [ -n "$GIT_C_PATH" ]; then
    GIT_COMMON_DIR=$(git -C "$GIT_C_PATH" rev-parse --git-common-dir 2>/dev/null || echo "")
    GIT_DIR=$(git -C "$GIT_C_PATH" rev-parse --git-dir 2>/dev/null || echo "")
    BRANCH=$(git -C "$GIT_C_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  else
    GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null || echo "")
    GIT_DIR=$(git rev-parse --git-dir 2>/dev/null || echo "")
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  fi

  # メインワークツリー判定: git-dir と common-dir が一致 = メインWT
  if [ "$GIT_DIR" = "$GIT_COMMON_DIR" ] || [ "$GIT_DIR" = ".git" ]; then
    if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ] || [ "$BRANCH" = "develop" ]; then
      cat << DENY
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[コミット衛生ガード] メインワークツリーの ${BRANCH} ブランチでの直接コミットはブロックされています。ブランチを作成して PR 経由でマージしてください。"
  }
}
DENY
      exit 0
    fi
  fi
fi

# --- チェック 1: --no-verify / -n (commit) ---
if echo "$COMMAND" | grep -qE 'git\s+commit\s.*--no-verify|git\s+commit\s.*\s-n\b'; then
  cat << 'DENY'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[コミット衛生ガード] --no-verify の使用はブロックされています。pre-commit フックのエラーを修正してからコミットしてください。"
  }
}
DENY
  exit 0
fi

# --- チェック 2: force push to main/master ---
if echo "$COMMAND" | grep -qE 'git\s+push\s.*--force|git\s+push\s.*-f\b'; then
  if echo "$COMMAND" | grep -qE '\b(main|master)\b'; then
    cat << 'DENY'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[コミット衛生ガード] main/master への force push はブロックされています。"
  }
}
DENY
    exit 0
  fi
fi

# --- チェック 3: メインワークツリーでの git checkout (ブランチ切り替え) ---
if echo "$COMMAND" | grep -qE 'git\s+checkout\s|git\s+switch\s'; then
  # ワークツリー判定
  GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null || echo "")
  GIT_DIR=$(git rev-parse --git-dir 2>/dev/null || echo "")

  if [ "$GIT_DIR" = "$GIT_COMMON_DIR" ] || [ "$GIT_DIR" = ".git" ]; then
    # メインワークツリーにいる
    cat << 'DENY'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[コミット衛生ガード] メインワークツリーでの git checkout/switch はブロックされています。`git worktree add` でワークツリーを作成してください。未コミットの作業が消失するリスクがあります。"
  }
}
DENY
    exit 0
  fi
fi

# --- チェック 4: メインワークツリーでの release/* マージ（main への直接マージ防止） ---
if echo "$COMMAND" | grep -qE 'git\s+merge\s.*release/'; then
  GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null || echo "")
  GIT_DIR=$(git rev-parse --git-dir 2>/dev/null || echo "")

  if [ "$GIT_DIR" = "$GIT_COMMON_DIR" ] || [ "$GIT_DIR" = ".git" ]; then
    cat << 'DENY'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[ブランチ戦略ガード] メインワークツリーでの release/* マージはブロックされています。release/* -> develop -> main の順でマージしてください。"
  }
}
DENY
    exit 0
  fi
fi

# --- チェック 5: develop ブランチの削除 ---
if echo "$COMMAND" | grep -qE 'git\s+branch\s.*-[dD]\s(.*\s)?develop(\s|$)|git\s+push\s.*--delete\s(.*\s)?develop(\s|$)|git\s+push\s.*:develop(\s|$)'; then
  cat << 'DENY'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[ブランチ戦略ガード] develop ブランチの削除はブロックされています。develop は永続ブランチです。"
  }
}
DENY
  exit 0
fi

# --- チェック 6: メインワークツリーでの git stash pop/apply ---
if echo "$COMMAND" | grep -qE 'git\s+stash\s+(pop|apply)'; then
  GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null || echo "")
  GIT_DIR=$(git rev-parse --git-dir 2>/dev/null || echo "")

  if [ "$GIT_DIR" = "$GIT_COMMON_DIR" ] || [ "$GIT_DIR" = ".git" ]; then
    cat << 'DENY'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[コミット衛生ガード] メインワークツリーでの git stash pop/apply はブロックされています。ワークツリー内で作業してください。"
  }
}
DENY
    exit 0
  fi
fi

exit 0
