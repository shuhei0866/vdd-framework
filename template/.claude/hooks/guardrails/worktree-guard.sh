#!/bin/bash
# worktree-guard: PreToolUse (Write|Edit) - メインワークツリーでのファイル編集をブロック [L5]
#
# メインワークツリー（リポジトリルート）でのファイル編集を技術的にブロックする。
# ワークツリー内、または除外パス（.claude/, CLAUDE.md 等）への書き込みは許可。

set -uo pipefail

INPUT=$(cat)

# file_path を取得
if command -v jq &>/dev/null; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
else
  # jq がない場合はスキップ（安全側に倒す）
  exit 0
fi

# パストラバーサル防止: .. を含むパスを正規化
FILE_PATH=$(realpath -m "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")

if [ -z "${FILE_PATH:-}" ]; then
  exit 0
fi

# プロジェクトルートを取得
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$PROJECT_ROOT" ]; then
  exit 0
fi

# 現在のディレクトリがワークツリーかどうかを判定
# git worktree 内では git rev-parse --show-toplevel がワークツリーのルートを返す
# メインワークツリーでは git の common dir と toplevel が一致する
GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null || echo "")
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null || echo "")

# ワークツリー内にいる場合（.git がファイルで common dir と異なる）は許可
if [ "$GIT_DIR" != "$GIT_COMMON_DIR" ] && [ "$GIT_DIR" != ".git" ]; then
  exit 0
fi

# ファイルパスがワークツリー内かチェック（CWD がメインWT でもファイル自体がWT内なら許可）
while IFS= read -r line; do
  case "$line" in
    worktree\ *)
      WT_PATH="${line#worktree }"
      # メインワークツリーはスキップ
      if [ "$WT_PATH" = "$PROJECT_ROOT" ]; then
        continue
      fi
      # ワークツリーパスも正規化してから比較（パストラバーサル対策）
      WT_PATH_NORMALIZED=$(realpath -m "$WT_PATH" 2>/dev/null || echo "$WT_PATH")
      # ファイルがこのワークツリー内にある場合は許可
      case "$FILE_PATH" in
        "$WT_PATH_NORMALIZED"/*)
          exit 0
          ;;
      esac
      ;;
  esac
done < <(git worktree list --porcelain 2>/dev/null)

# ファイルパスがプロジェクトルート配下かチェック
case "$FILE_PATH" in
  "$PROJECT_ROOT"/*)
    # プロジェクト内のファイル - 除外パスをチェック
    ;;
  *)
    # プロジェクト外のファイル - 許可
    exit 0
    ;;
esac

# 除外パス: これらはメインワークツリーでの編集を許可
RELATIVE_PATH="${FILE_PATH#$PROJECT_ROOT/}"
case "$RELATIVE_PATH" in
  .claude/*)         exit 0 ;;  # Claude Code 設定・メモリ
  CLAUDE.md)         exit 0 ;;  # 自己改善プロトコル
  .gitignore)        exit 0 ;;  # gitignore の更新
  .github/*)         exit 0 ;;  # CI/CD 設定
esac

# メインワークツリーでの編集をブロック
cat << DENY
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[ワークツリーガード] メインワークツリーでのファイル編集はブロックされています。\n\n⚠️ 重要: Edit, Write, Bash redirect など別の方法でのリトライは禁止です。すべて同様にブロックされます。\n\n対処法: ユーザーに報告し、\`git worktree add .worktrees/<name> <branch>\` でワークツリーを作成してそこで作業してください。\n\n編集しようとしたファイル: ${RELATIVE_PATH}"
  }
}
DENY
