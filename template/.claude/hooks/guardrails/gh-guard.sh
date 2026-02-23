#!/bin/bash
# gh-guard: PreToolUse (Bash) - PR 操作をブロック [L5]
#
# ローカル環境: main 向け PR の approve/merge のみブロック。
#               release/* → develop のマージは許可。
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
# curl や gh api で GitHub REST API の merge/review エンドポイントを直接叩くのをブロック
# パターン: PUT /repos/{owner}/{repo}/pulls/{number}/merge
#           POST /repos/{owner}/{repo}/pulls/{number}/reviews (approve)
if echo "$COMMAND" | grep -qiE '(curl|gh\s+api)\s'; then
  # merge API の検出: /pulls/xxx/merge（main 向けのみブロック）
  if echo "$COMMAND" | grep -qiE '/pulls/[0-9]+/merge'; then
    # curl/gh api での merge は base ブランチの判別が困難なため、安全のためブロック
    emit_deny "GitHub API 経由の PR マージはブロックされています。gh pr merge コマンドを使用してください。"
  fi
  # review/approve API の検出: /pulls/xxx/reviews と APPROVE を含む
  if echo "$COMMAND" | grep -qiE '/pulls/[0-9]+/reviews'; then
    if echo "$COMMAND" | grep -qiE 'approve'; then
      emit_deny "GitHub API 経由の PR approve はブロックされています。gh pr review --approve も curl/gh api による直接呼び出しも禁止です。"
    fi
  fi
fi

# gh pr コマンド以外はスキップ（curl/gh api は上でチェック済み）
case "$COMMAND" in
  *gh\ pr\ *)
    ;;
  *)
    exit 0
    ;;
esac

# --- ヘルパー: PR のターゲットブランチを取得 ---
# フェイルクローズ設計: gh pr view が失敗した場合は "__UNKNOWN__" を返す。
# 呼び出し元で "__UNKNOWN__" を検出して deny する。
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
# positional argument のみを PR 番号として扱い、--body 等の引数内の数字を無視する。
extract_pr_number() {
  local cmd="$1"
  local subcmd="$2"
  # "gh pr <subcmd>" 以降の部分を抽出
  local args
  args=$(echo "$cmd" | sed -E "s/.*gh[[:space:]]+pr[[:space:]]+${subcmd}[[:space:]]+//")

  # 値を取るフラグとその値を除去（引用符付き値 → 引用符なし値の順）
  args=$(echo "$args" | sed -E 's/(--body-file|--body|-b|--subject|-t|--match-head-commit|--author|-R|--repo)[[:space:]]+"[^"]*"//g')
  args=$(echo "$args" | sed -E "s/(--body-file|--body|-b|--subject|-t|--match-head-commit|--author|-R|--repo)[[:space:]]+'[^']*'//g")
  args=$(echo "$args" | sed -E 's/(--body-file|--body|-b|--subject|-t|--match-head-commit|--author|-R|--repo)[[:space:]]+[^[:space:]]+//g')

  # --flag=value パターンを除去（引用符付き含む）
  args=$(echo "$args" | sed -E 's/--[a-zA-Z-]+="[^"]*"//g')
  args=$(echo "$args" | sed -E "s/--[a-zA-Z-]+='[^']*'//g")
  args=$(echo "$args" | sed -E 's/--[a-zA-Z-]+=[^[:space:]]+//g')

  # 残りのフラグを除去
  args=$(echo "$args" | sed -E 's/--?[a-zA-Z-]+//g')

  # 残った引用符を除去（"123" → 123 に対応）
  args=$(echo "$args" | sed -E "s/[\"']//g")

  # PR 番号を抽出（残った positional argument から）
  echo "$args" | grep -oE '\b[0-9]+\b' | head -1
}

# --- ヘルパー: approve の deny 判定 ---
# クラウド環境: 全 PR をブロック（自己 approve 防止、常に true）
# ローカル環境: main/master または不明の場合のみ true
should_deny_approve() {
  local base="$1"
  if [ "$IS_CLOUD" = "1" ]; then
    return 0  # クラウドでは常にブロック
  fi
  [ "$base" = "main" ] || [ "$base" = "master" ] || [ "$base" = "__UNKNOWN__" ]
}

# --- ヘルパー: merge の deny 判定 ---
# 両環境共通: main/master または不明の場合のみブロック
# クラウド環境でも develop 向け merge は許可（レビュアー approve 確認後）
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
      emit_deny "${REASON} develop → main の昇格は人間が承認・実行してください。"
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
    emit_deny "${REASON} develop → main の昇格は人間が実行してください。"
  fi
fi

exit 0
