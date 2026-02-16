#!/bin/bash
# rdd-reminder: UserPromptSubmit 時に RDD ワークフローのコンテキストを注入する
# 実装系のキーワードが含まれる場合にリマインドを出す

set -uo pipefail

INPUT=$(cat)

# prompt テキストを取得
if command -v jq &>/dev/null; then
  PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')
else
  PROMPT=$(echo "$INPUT" | grep -o '"prompt":"[^"]*"' | sed 's/"prompt":"//;s/"//')
fi

if [ -z "${PROMPT:-}" ]; then
  exit 0
fi

# 実装系キーワードの検出（日本語 + 英語）
if echo "$PROMPT" | grep -qiE '実装|作って|追加|修正|変更|削除|更新|移行|導入|改修|直して|書いて|組み込|統合|fix|implement|add|create|build|機能|feature|リファクタ|refactor|deploy|migrate'; then
  # 現在のブランチを確認
  BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

  if [ "$BRANCH" = "main" ]; then
    cat << 'REMIND'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "[RDD リマインド] 実装リクエストを検出しました。RDD ワークフローに従ってください: (1) 設計対話で方針を決める (2) リリース仕様書を作成 (3) release/* ブランチで実装 (4) /release-ready で自己評価。現在 main ブランチにいます。まず release/* ブランチを作成してください。"
  }
}
REMIND
    exit 0
  fi
fi

exit 0
