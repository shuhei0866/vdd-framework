#!/bin/bash
# gh-guard: PreToolUse (Bash) - PR 操作をブロック [L5]
#
# ローカル環境: main 向け PR の approve/merge のみブロック。
#               release/* -> develop のマージは許可。
#
# クラウド環境 (CLAUDE_CLOUD=1): 全 PR の approve をブロック（自己 approve 防止）。
#               merge は develop 向けのみ許可（レビュアー approve 確認後）。
#               main 向け merge は両環境でブロック。
#
# 両環境共通: curl / gh api による GitHub approve API 直接呼び出しもブロック。

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

# --- クラウド環境判定 ---
IS_CLOUD="${CLAUDE_CLOUD:-0}"

# --- ヘルパー: deny レスポンスを出力 ---
emit_deny() {
  local reason="$1"
  cat << DENY
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[GH ガード] ${reason}"
  }
}
DENY
  exit 0
}

# --- チェック 0: curl / gh api による GitHub merge/approve API 直接呼び出し ---
if echo "$COMMAND" | grep -qiE '(curl|gh\s+api)\s'; then
  # merge API の検出
  if echo "$COMMAND" | grep -qiE '/pulls/[0-9]+/merge'; then
    emit_deny "GitHub API 経由の PR マージはブロックされています。gh pr merge コマンドを使用してください。"
  fi
  # review/approve API の検出
  if echo "$COMMAND" | grep -qiE '/pulls/[0-9]+/reviews'; then
    if echo "$COMMAND" | grep -qiE 'approve'; then
      emit_deny "GitHub API 経由の PR approve はブロックされています。"
    fi
  fi
fi

# gh pr コマンド以外はスキップ
case "$COMMAND" in
  *gh\ pr\ *)
    ;;
  *)
    exit 0
    ;;
esac

# --- ヘルパー: PR のターゲットブランチを取得 ---
# フェイルクローズ設計: gh pr view が失敗した場合は "__UNKNOWN__" を返す。
get_pr_base() {
  local pr_num="$1"
  local result
  if [ -n "$pr_num" ]; then
    result=$(gh pr view "$pr_num" --json baseRefName -q .baseRefName 2>/dev/null) || true
  else
    result=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null) || true
  fi
  if [ -z "$result" ]; then
    echo "__UNKNOWN__"
  else
    echo "$result"
  fi
}

# --- ヘルパー: コマンドから PR 番号を抽出 ---
extract_pr_number() {
  local cmd="$1"
  local subcmd="$2"
  echo "$cmd" | grep -oE "gh\s+pr\s+${subcmd}\s+.*" | grep -oE '\b[0-9]+\b' | head -1
}

# --- ヘルパー: approve の deny 判定 ---
should_deny_approve() {
  local base="$1"
  if [ "$IS_CLOUD" = "1" ]; then
    return 0  # クラウドでは常にブロック
  fi
  [ "$base" = "main" ] || [ "$base" = "master" ] || [ "$base" = "__UNKNOWN__" ]
}

# --- ヘルパー: merge の deny 判定 ---
should_deny_merge() {
  local base="$1"
  [ "$base" = "main" ] || [ "$base" = "master" ] || [ "$base" = "__UNKNOWN__" ]
}

# --- チェック 1: gh pr review --approve ---
if echo "$COMMAND" | grep -qE 'gh\s+pr\s+review\s.*(-a\b|--approve)'; then
  PR_NUM=$(extract_pr_number "$COMMAND" "review")
  BASE=$(get_pr_base "$PR_NUM")

  if should_deny_approve "$BASE"; then
    if [ "$IS_CLOUD" = "1" ]; then
      emit_deny "クラウド環境では全 PR の approve がブロックされています。approve は独立レビュアーが実行します。"
    else
      REASON="main 向け PR の approve はブロックされています。"
      [ "$BASE" = "__UNKNOWN__" ] && REASON="PR のターゲットブランチを確認できなかったため、安全のためブロックしました。"
      emit_deny "${REASON} develop -> main の昇格は人間が承認・実行してください。"
    fi
  fi
fi

# --- チェック 2: gh pr merge ---
if echo "$COMMAND" | grep -qE 'gh\s+pr\s+merge'; then
  PR_NUM=$(extract_pr_number "$COMMAND" "merge")
  BASE=$(get_pr_base "$PR_NUM")

  if should_deny_merge "$BASE"; then
    REASON="main 向け PR のマージはブロックされています。"
    [ "$BASE" = "__UNKNOWN__" ] && REASON="PR のターゲットブランチを確認できなかったため、安全のためブロックしました。"
    emit_deny "${REASON} develop -> main の昇格は人間が実行してください。"
  fi
fi

exit 0
