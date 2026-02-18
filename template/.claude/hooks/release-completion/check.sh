#!/bin/bash
# release-completion/check.sh: Stop - release/* ブランチでのリリース完了を検証
#
# ゴール + 出口ゲートパターンの実装。
# 「develop にマージまでやり切れ」というゴールの完了条件を機械的に検証する。
#
# 検証する完了条件:
# 1. リリース仕様書が存在すること
# 2. エージェントメモリに未コミットの変更がないこと
# 3. PR が develop にマージ済みであること

set -uo pipefail

INPUT=$(cat)

# vdd.config から設定を読み込む
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../vdd.config" 2>/dev/null || true

# デフォルト値
RELEASE_SPECS_DIR="${RELEASE_SPECS_DIR:-.claude/release-specs}"
AGENT_MEMORY_DIR="${AGENT_MEMORY_DIR:-.claude/agent-memory}"
INTEGRATION_BRANCH="${INTEGRATION_BRANCH:-develop}"

# stop_hook_active チェック（無限ループ防止）
if command -v jq &>/dev/null; then
  STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
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

# リリース名を抽出
RELEASE_NAME="${BRANCH#release/}"

ISSUES=""

# ゲート 1: リリース仕様書の存在確認
SPEC_FILE="${RELEASE_SPECS_DIR}/${RELEASE_NAME}.md"
if [ ! -f "$SPEC_FILE" ]; then
  ISSUES="${ISSUES}\n- リリース仕様書が見つかりません: ${SPEC_FILE}"
fi

# ゲート 2: エージェントメモリの未コミット変更
if [ -d "$AGENT_MEMORY_DIR" ]; then
  UNCOMMITTED=$(git status --porcelain "$AGENT_MEMORY_DIR" 2>/dev/null | head -5)
  if [ -n "$UNCOMMITTED" ]; then
    ISSUES="${ISSUES}\n- エージェントメモリに未コミットの変更があります: ${AGENT_MEMORY_DIR}"
  fi
fi

# ゲート 3: PR が develop にマージ済みか
if command -v gh &>/dev/null; then
  MERGED_PR=$(gh pr list --head "$BRANCH" --base "$INTEGRATION_BRANCH" --state merged --json number --jq '.[0].number' 2>/dev/null)
  if [ -z "$MERGED_PR" ]; then
    ISSUES="${ISSUES}\n- PR が ${INTEGRATION_BRANCH} にマージされていません。PR を作成してマージしてください。"
  fi
fi

if [ -n "$ISSUES" ]; then
  # 改行をエスケープして JSON に埋め込む
  ESCAPED_ISSUES=$(echo -e "$ISSUES" | jq -Rs '.')
  cat << EOF
{
  "decision": "block",
  "reason": "[リリース完了ゲート] 以下の完了条件が未達成です:${ISSUES}\n\nゴール: ${INTEGRATION_BRANCH} にマージするところまでやり切ってください。"
}
EOF
else
  exit 0
fi
