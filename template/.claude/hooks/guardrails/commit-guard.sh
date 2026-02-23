#!/bin/bash
# commit-guard: PreToolUse (Bash) - 危険な git 操作をブロック [L5]
#
# メインワークツリーでの保護ブランチ (main/develop) への直接コミット、
# --no-verify によるフックスキップ、force push、ブランチ切り替え、
# main への直接マージ（hotfix 除く）、develop ブランチ削除などを検出してブロックする。
# gh pr merge による main 向け PR マージもブロック。

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

# パターンマッチ用: 引用符内のテキストを除去（コマンド引数の誤検出防止）
# 値の抽出には元の COMMAND を使用する
COMMAND_FOR_MATCH=$(echo "$COMMAND" | sed -E "s/\"[^\"]*\"//g; s/'[^']*'//g")

# git/gh コマンド以外はスキップ
case "$COMMAND_FOR_MATCH" in
  *git\ *|*gh\ *)
    ;;
  *)
    exit 0
    ;;
esac

# --- チェック 0: メインワークツリーでの git commit (保護ブランチ直接コミット防止) ---
# 注意: PreToolUse フックはメインワークツリーの CWD で実行される。
# git -C <path> または cd <path> && git commit でワークツリーを指定するケースがあるため、
# -C パスおよび cd パスを考慮して判定する。
if echo "$COMMAND_FOR_MATCH" | grep -qE 'git\s+(-C\s+\S+\s+)?commit\b'; then
  # コマンドから -C パスを抽出（あれば）
  GIT_C_PATH=$(echo "$COMMAND" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^ ]+).*/\1/p')

  # cd <path> パターンを検出（cd path && git commit など）
  # cd が git commit より前にある場合のみ抽出（後ろにある場合は無視）
  BEFORE_GIT=$(echo "$COMMAND" | sed -nE 's/(.*)(git[[:space:]]+(-C[[:space:]]+[^ ]+[[:space:]]+)?commit\b.*)/\1/p')
  CD_PATH=$(echo "$BEFORE_GIT" | sed -nE 's/.*cd[[:space:]]+([^ &;|]+).*/\1/p')

  if [ -n "$GIT_C_PATH" ]; then
    # git -C <path> パターン
    GIT_COMMON_DIR=$(git -C "$GIT_C_PATH" rev-parse --git-common-dir 2>/dev/null || echo "")
    GIT_DIR=$(git -C "$GIT_C_PATH" rev-parse --git-dir 2>/dev/null || echo "")
    BRANCH=$(git -C "$GIT_C_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  elif [ -n "$CD_PATH" ] && [ -d "$CD_PATH" ]; then
    # cd <path> パターン: cd でディレクトリ変更後に git commit するケース
    GIT_COMMON_DIR=$(git -C "$CD_PATH" rev-parse --git-common-dir 2>/dev/null || echo "")
    GIT_DIR=$(git -C "$CD_PATH" rev-parse --git-dir 2>/dev/null || echo "")
    BRANCH=$(git -C "$CD_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  else
    # メインワークツリー（CWD）で判定
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
    "permissionDecisionReason": "[コミット衛生ガード] メインワークツリーの ${BRANCH} ブランチでの直接コミットはブロックされています。ブランチを作成して PR 経由でマージしてください。.claude/ の変更も含め、ワークツリーまたは別ブランチで作業してください。"
  }
}
DENY
      exit 0
    fi
  fi
fi

# --- チェック 1: --no-verify / -n (commit) ---
if echo "$COMMAND_FOR_MATCH" | grep -qE 'git\s+commit\s.*--no-verify|git\s+commit\s.*\s-n\b'; then
  cat << 'DENY'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[コミット衛生ガード] --no-verify の使用はブロックされています。pre-commit フックのエラーを修正してからコミットしてください。lint エラーの場合は `pnpm lint --fix` を試してください。"
  }
}
DENY
  exit 0
fi

# --- チェック 2: force push to main/master ---
if echo "$COMMAND_FOR_MATCH" | grep -qE 'git\s+push\s.*--force|git\s+push\s.*-f\b'; then
  if echo "$COMMAND_FOR_MATCH" | grep -qE '\b(main|master)\b'; then
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
if echo "$COMMAND_FOR_MATCH" | grep -qE 'git\s+checkout\s|git\s+switch\s'; then
  # ワークツリー判定
  GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null || echo "")
  GIT_DIR=$(git rev-parse --git-dir 2>/dev/null || echo "")

  if [ "$GIT_DIR" = "$GIT_COMMON_DIR" ] || [ "$GIT_DIR" = ".git" ]; then
    # メインワークツリーにいる
    # develop/main/master への切り替えは許可（永続ブランチとの同期用途）
    # ただし "git checkout main -- file" のファイル復元パターンは除外
    if echo "$COMMAND_FOR_MATCH" | grep -qE 'git\s+(checkout|switch)\s+(develop|main|master)(\s|$|&|;)'; then
      if ! echo "$COMMAND_FOR_MATCH" | grep -qE 'git\s+(checkout|switch)\s+(develop|main|master)\s+--'; then
        exit 0
      fi
    fi
    cat << 'DENY'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[コミット衛生ガード] メインワークツリーでの git checkout/switch はブロックされています。`git worktree add` でワークツリーを作成してください。未コミットの作業が消失するリスクがあります。（develop/main への切り替えは許可されています）"
  }
}
DENY
    exit 0
  fi
fi

# --- チェック 4: main ブランチへの直接マージ防止（hotfix/* 除く） ---
# main への直接マージは hotfix/* のみ許可。それ以外は develop 経由を必須とする。
# -C パスの有無を考慮して、マージ先ブランチを正確に判定する。
if echo "$COMMAND_FOR_MATCH" | grep -qE 'git\s+(-C\s+\S+\s+)?merge\s'; then
  # hotfix/* は例外として許可
  if ! echo "$COMMAND_FOR_MATCH" | grep -qE 'git\s+(-C\s+\S+\s+)?merge\s.*hotfix/'; then
    # -C パスを抽出（あれば）
    GIT_C_PATH=$(echo "$COMMAND" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^ ]+).*/\1/p')

    if [ -n "$GIT_C_PATH" ]; then
      CURRENT_BRANCH=$(git -C "$GIT_C_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    else
      CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    fi

    if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
      cat << 'DENY'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[ブランチ戦略ガード] main への直接マージはブロックされています。develop 経由でマージしてください。hotfix の場合は hotfix/* ブランチを使用してください。"
  }
}
DENY
      exit 0
    fi
  fi
fi

# --- チェック 4b: gh pr merge で main 向け PR のマージ防止（hotfix/* 除く） ---
# --body 引数内の誤検出を防ぐため、コマンド先頭またはシェル演算子直後のみマッチ
if echo "$COMMAND_FOR_MATCH" | grep -qE '(^|&&|\|\||[;|])\s*gh\s+pr\s+merge'; then
  # PR 番号を抽出（gh pr merge 123 ...）
  PR_NUM=$(echo "$COMMAND" | grep -oE '(^|&&|\|\||[;|])\s*gh[[:space:]]+pr[[:space:]]+merge[[:space:]]+([0-9]+)' | grep -oE '[0-9]+' | head -1)

  if [ -n "$PR_NUM" ]; then
    PR_VIEW_ARGS="$PR_NUM"
  else
    PR_VIEW_ARGS=""
  fi

  # PR の base branch と head branch を取得
  PR_INFO=$(gh pr view $PR_VIEW_ARGS --json baseRefName,headRefName 2>/dev/null || echo "")
  if [ -n "$PR_INFO" ]; then
    BASE_BRANCH=$(echo "$PR_INFO" | jq -r '.baseRefName // empty')
    HEAD_BRANCH=$(echo "$PR_INFO" | jq -r '.headRefName // empty')

    if [ "$BASE_BRANCH" = "main" ] || [ "$BASE_BRANCH" = "master" ]; then
      # hotfix/* は例外
      if ! echo "$HEAD_BRANCH" | grep -qE '^hotfix/'; then
        cat << DENY
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[ブランチ戦略ガード] ${HEAD_BRANCH} → ${BASE_BRANCH} への PR マージはブロックされています。develop を経由してマージしてください。hotfix の場合は hotfix/* ブランチを使用してください。"
  }
}
DENY
        exit 0
      fi
    fi
  fi
fi

# --- チェック 5: develop ブランチの削除 ---
if echo "$COMMAND_FOR_MATCH" | grep -qE 'git\s+branch\s.*-[dD]\s(.*\s)?develop(\s|$)|git\s+push\s.*--delete\s(.*\s)?develop(\s|$)|git\s+push\s.*:develop(\s|$)'; then
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
if echo "$COMMAND_FOR_MATCH" | grep -qE 'git\s+stash\s+(pop|apply)'; then
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
