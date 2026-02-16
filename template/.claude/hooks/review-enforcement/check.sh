#!/bin/bash
# review-enforcement/check.sh: Stop - release/* ブランチでのレビューステップ実行を検証
#
# release/* ブランチで作業が行われた場合、/release-ready と /review-now が
# 実行されたかを transcript から検証する。未実行の場合は block して警告。

set -uo pipefail

INPUT=$(cat)

# stop_hook_active チェック（無限ループ防止）
if command -v jq &>/dev/null; then
  STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
  TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
else
  exit 0
fi

if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# 現在のブランチを確認
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

# release/* ブランチでない場合はスキップ
case "$BRANCH" in
  release/*)
    ;;
  *)
    exit 0
    ;;
esac

# transcript が存在しない場合はスキップ
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# transcript 内で /release-ready と /review-now の実行痕跡を検索
HAS_RELEASE_READY=false
HAS_REVIEW_NOW=false

if grep -q "release-ready" "$TRANSCRIPT_PATH" 2>/dev/null; then
  HAS_RELEASE_READY=true
fi

if grep -q "review-now" "$TRANSCRIPT_PATH" 2>/dev/null; then
  HAS_REVIEW_NOW=true
fi

# 設計対話フェーズの判定: コードの変更がない場合はレビュー不要
CODE_CHANGES=$(git diff main --name-only 2>/dev/null | grep -v -E '^\.claude/' | head -1)
if [ -z "$CODE_CHANGES" ]; then
  exit 0
fi

# レビュー実行チェック
MISSING=""
if [ "$HAS_RELEASE_READY" = "false" ]; then
  MISSING="/release-ready"
fi
if [ "$HAS_REVIEW_NOW" = "false" ]; then
  if [ -n "$MISSING" ]; then
    MISSING="$MISSING, /review-now"
  else
    MISSING="/review-now"
  fi
fi

if [ -n "$MISSING" ]; then
  cat << EOF
{
  "decision": "block",
  "reason": "[レビュー強制] release/* ブランチでコード変更がありますが、以下のレビューステップが未実行です: ${MISSING}。PR 作成前に実行してください。"
}
EOF
else
  exit 0
fi
