#!/bin/bash
# test-hooks.sh - VDD Framework Hook テストスイート
#
# 使い方:
#   bash tests/test-hooks.sh
#
# 各 hook スクリプトに対してモック JSON を stdin で渡し、
# exit code と出力を検証する。テスト用の一時 git リポジトリを作成して実行。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$FRAMEWORK_ROOT/template"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

# === 色定義 ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# === カウンター ===
PASS=0
FAIL=0
TOTAL=0

# === テストユーティリティ ===

# 一時ディレクトリ管理
TEMP_DIRS=()
cleanup() {
  for dir in "${TEMP_DIRS[@]}"; do
    rm -rf "$dir" 2>/dev/null || true
  done
}
trap cleanup EXIT

# テスト用 git リポジトリを作成
create_test_repo() {
  local tmpdir
  tmpdir=$(mktemp -d)
  TEMP_DIRS+=("$tmpdir")

  cd "$tmpdir"
  git init --quiet
  git commit --allow-empty -m "initial" --quiet
  # macOS では /var -> /private/var のシンボリックリンクがあるため、
  # git rev-parse --show-toplevel と一致するよう実パスを返す
  cd "$tmpdir" && pwd -P
}

# フィクスチャの {{PROJECT_ROOT}} を置換
prepare_fixture() {
  local fixture="$1"
  local project_root="$2"

  if [[ "$(uname)" == "Darwin" ]]; then
    sed "s|{{PROJECT_ROOT}}|${project_root}|g" "$fixture"
  else
    sed "s|{{PROJECT_ROOT}}|${project_root}|g" "$fixture"
  fi
}

# テスト実行: hook が deny を返すことを期待
assert_deny() {
  local test_name="$1"
  local hook_script="$2"
  local input="$3"
  local working_dir="${4:-}"

  ((TOTAL++))

  local output exit_code
  if [ -n "$working_dir" ]; then
    output=$(cd "$working_dir" && echo "$input" | bash "$hook_script" 2>/dev/null) || true
    exit_code=$?
  else
    output=$(echo "$input" | bash "$hook_script" 2>/dev/null) || true
    exit_code=$?
  fi

  if echo "$output" | grep -q '"permissionDecision": "deny"' 2>/dev/null; then
    echo -e "  ${GREEN}PASS${NC} $test_name"
    ((PASS++))
  else
    echo -e "  ${RED}FAIL${NC} $test_name"
    echo -e "       期待: deny を含む出力"
    echo -e "       実際: $(echo "$output" | head -3)"
    ((FAIL++))
  fi
}

# テスト実行: hook が許可（exit 0, deny なし）を返すことを期待
assert_allow() {
  local test_name="$1"
  local hook_script="$2"
  local input="$3"
  local working_dir="${4:-}"

  ((TOTAL++))

  local output
  if [ -n "$working_dir" ]; then
    output=$(cd "$working_dir" && echo "$input" | bash "$hook_script" 2>/dev/null) || true
  else
    output=$(echo "$input" | bash "$hook_script" 2>/dev/null) || true
  fi

  if echo "$output" | grep -q '"permissionDecision": "deny"' 2>/dev/null; then
    echo -e "  ${RED}FAIL${NC} $test_name"
    echo -e "       期待: 許可（deny なし）"
    echo -e "       実際: deny が返されました"
    ((FAIL++))
  else
    echo -e "  ${GREEN}PASS${NC} $test_name"
    ((PASS++))
  fi
}

# テスト実行: hook が block を返すことを期待
assert_block() {
  local test_name="$1"
  local hook_script="$2"
  local input="$3"
  local working_dir="${4:-}"

  ((TOTAL++))

  local output
  if [ -n "$working_dir" ]; then
    output=$(cd "$working_dir" && echo "$input" | bash "$hook_script" 2>/dev/null) || true
  else
    output=$(echo "$input" | bash "$hook_script" 2>/dev/null) || true
  fi

  if echo "$output" | grep -q '"decision": "block"' 2>/dev/null; then
    echo -e "  ${GREEN}PASS${NC} $test_name"
    ((PASS++))
  else
    echo -e "  ${RED}FAIL${NC} $test_name"
    echo -e "       期待: block を含む出力"
    echo -e "       実際: $(echo "$output" | head -3)"
    ((FAIL++))
  fi
}

# テスト実行: hook が additionalContext を返すことを期待
assert_context() {
  local test_name="$1"
  local hook_script="$2"
  local input="$3"
  local expected_text="$4"
  local working_dir="${5:-}"

  ((TOTAL++))

  local output
  if [ -n "$working_dir" ]; then
    output=$(cd "$working_dir" && echo "$input" | bash "$hook_script" 2>/dev/null) || true
  else
    output=$(echo "$input" | bash "$hook_script" 2>/dev/null) || true
  fi

  if echo "$output" | grep -q "$expected_text" 2>/dev/null; then
    echo -e "  ${GREEN}PASS${NC} $test_name"
    ((PASS++))
  else
    echo -e "  ${RED}FAIL${NC} $test_name"
    echo -e "       期待: '$expected_text' を含む出力"
    echo -e "       実際: $(echo "$output" | head -3)"
    ((FAIL++))
  fi
}

# ===========================
# worktree-guard テスト
# ===========================

test_worktree_guard() {
  echo -e "\n${BOLD}=== worktree-guard.sh テスト ===${NC}\n"

  local hook="$TEMPLATE_DIR/.claude/hooks/guardrails/worktree-guard.sh"
  local repo
  repo=$(create_test_repo)

  # メインWT のプロジェクト内ファイルへの Write -> deny
  local input
  input=$(prepare_fixture "$FIXTURES_DIR/write-main-wt.json" "$repo")
  assert_deny "メインWT 内ファイルへの Write は deny" "$hook" "$input" "$repo"

  # .claude/ 配下への Write -> 許可
  input=$(prepare_fixture "$FIXTURES_DIR/write-claude-dir.json" "$repo")
  assert_allow ".claude/ 配下への Write は許可" "$hook" "$input" "$repo"

  # .worktrees/ 配下への Write -> 許可
  input=$(prepare_fixture "$FIXTURES_DIR/write-worktree.json" "$repo")
  assert_allow ".worktrees/ 配下への Write は許可" "$hook" "$input" "$repo"

  # プロジェクト外ファイルへの Write -> 許可
  input=$(prepare_fixture "$FIXTURES_DIR/write-outside-project.json" "$repo")
  assert_allow "プロジェクト外ファイルへの Write は許可" "$hook" "$input" "$repo"

  # file_path が空の場合 -> 許可（スキップ）
  local empty_input='{"tool_name": "Write", "tool_input": {}}'
  assert_allow "file_path が空の場合は許可" "$hook" "$empty_input" "$repo"

  # CLAUDE.md への Write -> 許可
  local claudemd_input
  claudemd_input=$(cat << EOF
{"tool_name": "Write", "tool_input": {"file_path": "$repo/CLAUDE.md", "content": "# test"}}
EOF
)
  assert_allow "CLAUDE.md への Write は許可" "$hook" "$claudemd_input" "$repo"

  # .gitignore への Write -> 許可
  local gitignore_input
  gitignore_input=$(cat << EOF
{"tool_name": "Write", "tool_input": {"file_path": "$repo/.gitignore", "content": "node_modules/"}}
EOF
)
  assert_allow ".gitignore への Write は許可" "$hook" "$gitignore_input" "$repo"

  # .github/ 配下への Write -> 許可
  local github_input
  github_input=$(cat << EOF
{"tool_name": "Write", "tool_input": {"file_path": "$repo/.github/workflows/ci.yml", "content": "name: CI"}}
EOF
)
  assert_allow ".github/ 配下への Write は許可" "$hook" "$github_input" "$repo"
}

# ===========================
# commit-guard テスト
# ===========================

test_commit_guard() {
  echo -e "\n${BOLD}=== commit-guard.sh テスト ===${NC}\n"

  local hook="$TEMPLATE_DIR/.claude/hooks/guardrails/commit-guard.sh"
  local repo
  repo=$(create_test_repo)

  # force push to main -> deny
  local input
  input=$(cat "$FIXTURES_DIR/bash-force-push.json")
  assert_deny "main への force push は deny" "$hook" "$input" "$repo"

  # --no-verify -> deny
  input=$(cat "$FIXTURES_DIR/bash-no-verify.json")
  assert_deny "--no-verify は deny" "$hook" "$input" "$repo"

  # git checkout main (メインWT) -> deny
  input=$(cat "$FIXTURES_DIR/bash-checkout-main.json")
  assert_deny "メインWT での git checkout は deny" "$hook" "$input" "$repo"

  # git stash pop (メインWT) -> deny
  input=$(cat "$FIXTURES_DIR/bash-stash-pop.json")
  assert_deny "メインWT での git stash pop は deny" "$hook" "$input" "$repo"

  # git merge release/* (メインWT) -> deny
  input=$(cat "$FIXTURES_DIR/bash-merge-release.json")
  assert_deny "メインWT での release/* マージは deny" "$hook" "$input" "$repo"

  # git branch -D develop -> deny
  input=$(cat "$FIXTURES_DIR/bash-delete-develop.json")
  assert_deny "develop ブランチの削除は deny" "$hook" "$input" "$repo"

  # 通常の git commit (release/* ブランチ) -> 許可
  # release ブランチを作成してワークツリーでテスト
  local wt_dir
  wt_dir=$(mktemp -d)
  TEMP_DIRS+=("$wt_dir")
  cd "$repo"
  git branch release/test 2>/dev/null || true
  git worktree add "$wt_dir" release/test --quiet 2>/dev/null || true

  input=$(cat "$FIXTURES_DIR/bash-normal-commit.json")
  assert_allow "ワークツリーでの通常 commit は許可" "$hook" "$input" "$wt_dir"

  # git 以外のコマンド -> 許可
  local non_git_input='{"tool_name": "Bash", "tool_input": {"command": "pnpm test"}}'
  assert_allow "git 以外のコマンドは許可" "$hook" "$non_git_input" "$repo"

  # 空コマンド -> 許可
  local empty_input='{"tool_name": "Bash", "tool_input": {}}'
  assert_allow "空コマンドは許可" "$hook" "$empty_input" "$repo"

  # force push to feature branch -> 許可（main/master 以外）
  local force_push_feature='{"tool_name": "Bash", "tool_input": {"command": "git push --force origin feature/test"}}'
  assert_allow "feature ブランチへの force push は許可" "$hook" "$force_push_feature" "$repo"

  # メインWT での main/develop 直接コミット -> deny
  # repo はデフォルトブランチ (main) にいる
  cd "$repo"
  git checkout -b main --quiet 2>/dev/null || true
  input=$(cat "$FIXTURES_DIR/bash-normal-commit.json")
  assert_deny "メインWT の main ブランチでの commit は deny" "$hook" "$input" "$repo"
}

# ===========================
# gh-guard テスト
# ===========================

test_gh_guard() {
  echo -e "\n${BOLD}=== gh-guard.sh テスト ===${NC}\n"

  local hook="$TEMPLATE_DIR/.claude/hooks/guardrails/gh-guard.sh"
  local repo
  repo=$(create_test_repo)

  # gh pr コマンド以外 -> 許可
  local non_gh_input='{"tool_name": "Bash", "tool_input": {"command": "pnpm build"}}'
  assert_allow "gh pr 以外のコマンドは許可" "$hook" "$non_gh_input" "$repo"

  # curl で GitHub merge API 直接呼び出し -> deny
  local curl_merge='{"tool_name": "Bash", "tool_input": {"command": "curl -X PUT https://api.github.com/repos/owner/repo/pulls/123/merge"}}'
  assert_deny "curl での PR merge API 呼び出しは deny" "$hook" "$curl_merge" "$repo"

  # curl で approve API 直接呼び出し -> deny
  local curl_approve='{"tool_name": "Bash", "tool_input": {"command": "curl -X POST https://api.github.com/repos/owner/repo/pulls/123/reviews -d approve"}}'
  assert_deny "curl での approve API 呼び出しは deny" "$hook" "$curl_approve" "$repo"

  # 空コマンド -> 許可
  local empty_input='{"tool_name": "Bash", "tool_input": {}}'
  assert_allow "空コマンドは許可" "$hook" "$empty_input" "$repo"
}

# ===========================
# rdd-reminder テスト
# ===========================

test_rdd_reminder() {
  echo -e "\n${BOLD}=== rdd-reminder.sh テスト ===${NC}\n"

  local hook="$TEMPLATE_DIR/.claude/hooks/rdd-reminder/remind.sh"
  local repo
  repo=$(create_test_repo)

  # main ブランチで実装キーワード -> リマインド
  cd "$repo"
  git checkout -b main --quiet 2>/dev/null || true

  local impl_input='{"prompt": "ログイン機能を実装してください"}'
  assert_context "main で実装キーワードはリマインド" "$hook" "$impl_input" "RDD" "$repo"

  # main ブランチで非実装キーワード -> リマインドなし
  local query_input='{"prompt": "このファイルの内容を教えて"}'
  assert_allow "main で非実装キーワードはリマインドなし" "$hook" "$query_input" "$repo"

  # release ブランチで実装キーワード -> リマインドなし
  cd "$repo"
  git checkout -b release/test --quiet 2>/dev/null || true

  assert_allow "release ブランチではリマインドなし" "$hook" "$impl_input" "$repo"

  # 空のプロンプト -> リマインドなし
  local empty_input='{"prompt": ""}'
  assert_allow "空プロンプトはリマインドなし" "$hook" "$empty_input" "$repo"

  # 英語の実装キーワード -> リマインド（main ブランチ）
  cd "$repo"
  git checkout main --quiet 2>/dev/null || true
  local eng_input='{"prompt": "implement the user authentication feature"}'
  assert_context "main で英語の実装キーワードもリマインド" "$hook" "$eng_input" "RDD" "$repo"
}

# ===========================
# subagent-rules テスト
# ===========================

test_subagent_rules() {
  echo -e "\n${BOLD}=== subagent-rules/inject.sh テスト ===${NC}\n"

  local hook="$TEMPLATE_DIR/.claude/hooks/subagent-rules/inject.sh"
  local repo
  repo=$(create_test_repo)

  # implementer エージェント -> TDD ルールが注入される
  local impl_input='{"agent_type": "implementer"}'
  assert_context "implementer には TDD ルールが注入される" "$hook" "$impl_input" "TDD" "$repo"

  # code-reviewer エージェント -> レビュー観点が注入される
  local reviewer_input='{"agent_type": "code-reviewer"}'
  assert_context "code-reviewer にはレビュー観点が注入される" "$hook" "$reviewer_input" "セキュリティ" "$repo"

  # Explore エージェント -> 読み取り専用ルールが注入される
  local explore_input='{"agent_type": "Explore"}'
  assert_context "Explore には読み取り専用ルールが注入される" "$hook" "$explore_input" "読み取り専用" "$repo"

  # 不明な agent_type -> ベースルールのみ注入
  local unknown_input='{"agent_type": "unknown-agent"}'
  assert_context "不明な agent_type にもベースルールは注入される" "$hook" "$unknown_input" "メインワークツリー" "$repo"

  # release/* ブランチの implementer -> レビュー義務が追加
  cd "$repo"
  git checkout -b release/test --quiet 2>/dev/null || true
  assert_context "release ブランチの implementer にはレビュー義務が追加" "$hook" "$impl_input" "release-ready" "$repo"
}

# ===========================
# review-enforcement テスト
# ===========================

test_review_enforcement() {
  echo -e "\n${BOLD}=== review-enforcement/check.sh テスト ===${NC}\n"

  local hook="$TEMPLATE_DIR/.claude/hooks/review-enforcement/check.sh"
  local repo
  repo=$(create_test_repo)

  # release/* ブランチでないときは何もしない
  cd "$repo"
  local input='{"stop_hook_active": false, "transcript_path": "/nonexistent"}'
  assert_allow "release 以外のブランチではスキップ" "$hook" "$input" "$repo"

  # stop_hook_active=true -> スキップ（無限ループ防止）
  cd "$repo"
  git checkout -b release/test --quiet 2>/dev/null || true
  local loop_input='{"stop_hook_active": true, "transcript_path": "/tmp/test.jsonl"}'
  assert_allow "stop_hook_active=true はスキップ" "$hook" "$loop_input" "$repo"

  # release/* ブランチでコード変更あり + レビュー未実行 -> block
  cd "$repo"
  # ダミーのコード変更を作成（.claude/ 以外）
  mkdir -p "$repo/src"
  echo "code" > "$repo/src/index.ts"
  git add . && git commit -m "add code" --quiet

  # transcript を作成（レビュー痕跡なし）
  local transcript
  transcript=$(mktemp)
  TEMP_DIRS+=("$transcript")
  echo '{"type": "human", "message": "implement feature"}' > "$transcript"

  local block_input
  block_input=$(cat << EOF
{"stop_hook_active": false, "transcript_path": "$transcript"}
EOF
)
  assert_block "レビュー未実行で block" "$hook" "$block_input" "$repo"

  # レビュー実行済みの transcript -> 許可
  echo '{"type": "human", "message": "run release-ready and review-now"}' > "$transcript"
  echo '{"type": "assistant", "message": "release-ready completed"}' >> "$transcript"
  echo '{"type": "assistant", "message": "review-now completed"}' >> "$transcript"
  assert_allow "レビュー実行済みは許可" "$hook" "$block_input" "$repo"
}

# ===========================
# メイン実行
# ===========================

main() {
  echo -e "${BOLD}VDD Framework Hook テストスイート${NC}"
  echo "======================================"

  # jq チェック
  if ! command -v jq &>/dev/null; then
    echo -e "${RED}エラー: jq が必要です${NC}"
    exit 1
  fi

  test_worktree_guard
  test_commit_guard
  test_gh_guard
  test_rdd_reminder
  test_subagent_rules
  test_review_enforcement

  # === サマリー ===
  echo ""
  echo "======================================"
  echo -e "${BOLD}テスト結果: $TOTAL 件実行${NC}"
  echo -e "  ${GREEN}PASS: $PASS${NC}"
  if [ "$FAIL" -gt 0 ]; then
    echo -e "  ${RED}FAIL: $FAIL${NC}"
    echo ""
    exit 1
  else
    echo -e "  ${GREEN}全テスト合格${NC}"
    echo ""
    exit 0
  fi
}

main "$@"
