#!/bin/bash
# commit-guard.sh のユニットテスト
# 実行: bash tests/guardrails/commit-guard.test.sh
#
# テスト方法:
# - テスト用 git リポジトリとワークツリーを作成
# - commit-guard.sh に JSON 入力を渡し、deny/allow を判定
# - cd パターンと git -C パターンの両方を検証

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GUARD_SCRIPT="$SCRIPT_DIR/../../template/.claude/hooks/guardrails/commit-guard.sh"

PASS=0
FAIL=0
TOTAL=0

# テスト用一時ディレクトリ
TMPDIR_BASE=$(mktemp -d)
MAIN_REPO="$TMPDIR_BASE/main-repo"
WORKTREE_DIR="$TMPDIR_BASE/worktree"

cleanup() {
  if [ -d "$WORKTREE_DIR" ]; then
    git -C "$MAIN_REPO" worktree remove "$WORKTREE_DIR" --force 2>/dev/null || true
  fi
  rm -rf "$TMPDIR_BASE"
}
trap cleanup EXIT

setup_test_repo() {
  mkdir -p "$MAIN_REPO"
  git -C "$MAIN_REPO" init -b main >/dev/null 2>&1
  git -C "$MAIN_REPO" config user.email "test@test.com"
  git -C "$MAIN_REPO" config user.name "Test"
  echo "init" > "$MAIN_REPO/README.md"
  git -C "$MAIN_REPO" add . >/dev/null 2>&1
  git -C "$MAIN_REPO" commit -m "init" >/dev/null 2>&1
  git -C "$MAIN_REPO" branch develop >/dev/null 2>&1
  git -C "$MAIN_REPO" branch release/test-feature >/dev/null 2>&1
  git -C "$MAIN_REPO" worktree add "$WORKTREE_DIR" release/test-feature >/dev/null 2>&1
}

# commit-guard.sh を実行して結果を返す
run_guard() {
  local command="$1"
  local cwd="${2:-$MAIN_REPO}"

  # jq で安全に JSON を構築
  local input
  input=$(jq -n --arg cmd "$command" '{"tool_input":{"command":$cmd}}')

  cd "$cwd" && echo "$input" | bash "$GUARD_SCRIPT" 2>/dev/null
}

test_case() {
  local desc="$1"
  local command="$2"
  local expected="$3"
  local cwd="${4:-$MAIN_REPO}"

  TOTAL=$((TOTAL + 1))

  local result
  result=$(run_guard "$command" "$cwd")

  if [ "$expected" = "deny" ]; then
    if echo "$result" | grep -q '"permissionDecision": "deny"'; then
      printf "  PASS: %s\n" "$desc"
      PASS=$((PASS + 1))
    else
      printf "  FAIL: %s (expected deny, got allow)\n" "$desc"
      printf "    command: %s\n" "$command"
      printf "    output: %s\n" "$result"
      FAIL=$((FAIL + 1))
    fi
  else
    if [ -z "$result" ] || ! echo "$result" | grep -q '"permissionDecision": "deny"'; then
      printf "  PASS: %s\n" "$desc"
      PASS=$((PASS + 1))
    else
      printf "  FAIL: %s (expected allow, got deny)\n" "$desc"
      printf "    command: %s\n" "$command"
      printf "    output: %s\n" "$result"
      FAIL=$((FAIL + 1))
    fi
  fi
}

# --- セットアップ ---
echo "Setting up test repository..."
setup_test_repo
echo ""

# --- チェック 0: メインワークツリーでの git commit ---
echo "=== Check 0: Main worktree commit detection ==="

test_case \
  "git commit on main branch in main WT -> deny" \
  "git commit -m test" \
  "deny"

git -C "$MAIN_REPO" checkout develop >/dev/null 2>&1
test_case \
  "git commit on develop branch in main WT -> deny" \
  "git commit -m test" \
  "deny"
git -C "$MAIN_REPO" checkout main >/dev/null 2>&1

test_case \
  "git -C <worktree> commit -> allow" \
  "git -C $WORKTREE_DIR commit -m test" \
  "allow"

test_case \
  "cd <worktree> && git commit -> allow (new pattern)" \
  "cd $WORKTREE_DIR && git commit -m test" \
  "allow"

test_case \
  "cd <worktree> && git add . && git commit -> allow (chained)" \
  "cd $WORKTREE_DIR && git add . && git commit -m test" \
  "allow"

test_case \
  "git -C <main-repo> commit on main -> deny" \
  "git -C $MAIN_REPO commit -m test" \
  "deny"

echo ""

# --- cd パスが存在しないディレクトリの場合 ---
echo "=== Check 0: cd with non-existent path ==="

test_case \
  "cd <non-existent> && git commit -> deny (falls back to main WT)" \
  "cd /tmp/nonexistent-path-xyz && git commit -m test" \
  "deny"

echo ""

# --- cd パスのバリエーション ---
echo "=== Check 0: cd with various path formats ==="

test_case \
  "cd with absolute path to worktree -> allow" \
  "cd $WORKTREE_DIR && git add -A && git commit -m message" \
  "allow"

echo ""

# --- cd が git commit の後にあるケース ---
echo "=== Check 0: cd after git commit (should NOT be used for detection) ==="

test_case \
  "git commit && cd <worktree> -> deny (cd is after commit)" \
  "git commit -m test && cd $WORKTREE_DIR" \
  "deny"

echo ""

# --- チェック 3: メインワークツリーでの git checkout ---
echo "=== Check 3: Main worktree checkout/switch ==="

test_case \
  "git checkout develop -> allow (永続ブランチへの同期)" \
  "git checkout develop" \
  "allow"

test_case \
  "git checkout main -> allow (永続ブランチへの同期)" \
  "git checkout main" \
  "allow"

test_case \
  "git checkout master -> allow (永続ブランチへの同期)" \
  "git checkout master" \
  "allow"

test_case \
  "git switch develop -> allow (永続ブランチへの同期)" \
  "git switch develop" \
  "allow"

test_case \
  "git switch main -> allow (永続ブランチへの同期)" \
  "git switch main" \
  "allow"

test_case \
  "git checkout feature-branch -> deny" \
  "git checkout feature-branch" \
  "deny"

test_case \
  "git checkout -- file.txt -> deny (ファイル復元)" \
  "git checkout -- file.txt" \
  "deny"

test_case \
  "git checkout release/some-feature -> deny" \
  "git checkout release/some-feature" \
  "deny"

test_case \
  "git checkout -b new-branch -> deny (新ブランチ作成)" \
  "git checkout -b new-branch" \
  "deny"

test_case \
  "git switch -c new-branch -> deny (新ブランチ作成)" \
  "git switch -c new-branch" \
  "deny"

# develop に続く引数がある場合のテスト（例: develop&& のパターンは不一致にすべき）
test_case \
  "git checkout develop-branch -> deny (develop ではない)" \
  "git checkout develop-branch" \
  "deny"

# ファイル復元パターン (git checkout main -- file) のブロック
test_case \
  "git checkout main -- file.txt -> deny (ファイル復元)" \
  "git checkout main -- file.txt" \
  "deny"

test_case \
  "git checkout develop -- src/ -> deny (ファイル復元)" \
  "git checkout develop -- src/" \
  "deny"

echo ""

# --- 引用符内テキストの誤検出防止 ---
echo "=== Quoted text false positive prevention ==="

test_case \
  'gh pr create --body "fixes git checkout issue" -> allow (git コマンドではない)' \
  'gh pr create --body "fixes git checkout issue"' \
  "allow"

test_case \
  'echo "git checkout main" -> allow (git コマンドではない)' \
  'echo "git checkout main"' \
  "allow"

echo ""

# --- サマリー ---
echo "=============================="
printf "Total: %d  Pass: %d  Fail: %d\n" "$TOTAL" "$PASS" "$FAIL"
echo "=============================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
