#!/bin/bash
# validate.sh - VDD Framework 設定検証スクリプト
#
# 使い方:
#   bash /path/to/vdd-framework/scripts/validate.sh
#
# 対象プロジェクトのルートディレクトリで実行すること。
# 既存の VDD 設定が正しいかを検証する。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$(pwd)"

# ライブラリ読み込み
source "$SCRIPT_DIR/lib/common.sh"

# カウンター
PASS=0
FAIL=0
WARN=0

# === テストヘルパー ===
assert_file_exists() {
  local file="$1"
  local desc="$2"
  if [ -f "$TARGET_DIR/$file" ]; then
    success "$desc"
    ((PASS++))
  else
    error "$desc ($file が見つかりません)"
    ((FAIL++))
  fi
}

assert_dir_exists() {
  local dir="$1"
  local desc="$2"
  if [ -d "$TARGET_DIR/$dir" ]; then
    success "$desc"
    ((PASS++))
  else
    error "$desc ($dir が見つかりません)"
    ((FAIL++))
  fi
}

assert_file_executable() {
  local file="$1"
  local desc="$2"
  if [ -f "$TARGET_DIR/$file" ] && [ -x "$TARGET_DIR/$file" ]; then
    success "$desc"
    ((PASS++))
  elif [ -f "$TARGET_DIR/$file" ]; then
    warn "$desc ($file に実行権限がありません)"
    ((WARN++))
  else
    error "$desc ($file が見つかりません)"
    ((FAIL++))
  fi
}

assert_gitignore_contains() {
  local entry="$1"
  local desc="$2"
  if [ -f "$TARGET_DIR/.gitignore" ] && grep -qxF "$entry" "$TARGET_DIR/.gitignore" 2>/dev/null; then
    success "$desc"
    ((PASS++))
  else
    warn "$desc (.gitignore に $entry がありません)"
    ((WARN++))
  fi
}

assert_json_valid() {
  local file="$1"
  local desc="$2"
  if [ -f "$TARGET_DIR/$file" ] && jq empty "$TARGET_DIR/$file" 2>/dev/null; then
    success "$desc"
    ((PASS++))
  elif [ -f "$TARGET_DIR/$file" ]; then
    error "$desc ($file は無効な JSON です)"
    ((FAIL++))
  else
    error "$desc ($file が見つかりません)"
    ((FAIL++))
  fi
}

# === 設定の存在確認からレベルを推定 ===
detect_level() {
  local level=0

  # Level 1 チェック
  if [ -f "$TARGET_DIR/.claude/hooks/guardrails/worktree-guard.sh" ] && \
     [ -f "$TARGET_DIR/.claude/hooks/guardrails/commit-guard.sh" ]; then
    level=1
  fi

  # Level 2 チェック
  if [ "$level" -ge 1 ] && \
     [ -f "$TARGET_DIR/.claude/hooks/rdd-reminder/remind.sh" ] && \
     [ -f "$TARGET_DIR/.claude/hooks/conversation-logger/log.sh" ]; then
    level=2
  fi

  # Level 3 チェック
  if [ "$level" -ge 2 ] && \
     [ -f "$TARGET_DIR/.claude/hooks/subagent-rules/inject.sh" ] && \
     [ -f "$TARGET_DIR/.claude/hooks/review-enforcement/check.sh" ] && \
     [ -d "$TARGET_DIR/.claude/agents" ]; then
    level=3
  fi

  # Level 4 チェック
  if [ "$level" -ge 3 ] && \
     [ -d "$TARGET_DIR/.claude/vdd" ] && \
     [ -f "$TARGET_DIR/.claude/vdd/VISION.md" ]; then
    level=4
  fi

  echo "$level"
}

# ===========================
# メイン処理
# ===========================

main() {
  header "VDD Framework 設定検証"
  echo ""

  # --- 前提条件 ---
  if ! command -v jq &>/dev/null; then
    error "jq がインストールされていません。検証を中止します。"
    exit 1
  fi

  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    error "git リポジトリ内で実行してください。"
    exit 1
  fi

  # --- レベル検出 ---
  local level
  level=$(detect_level)
  if [ "$level" -eq 0 ]; then
    error "VDD 設定が見つかりません。init.sh でセットアップしてください。"
    exit 1
  fi
  info "検出された採用レベル: Level $level"
  echo ""

  # --- Level 1: 基本ファイルの検証 ---
  header "Level 1: Safe Development"
  assert_file_exists ".claude/vdd.config" "vdd.config が存在する"
  assert_json_valid ".claude/settings.json" "settings.json が有効な JSON"
  assert_file_exists "CLAUDE.md" "CLAUDE.md が存在する"
  assert_dir_exists ".worktrees" ".worktrees/ ディレクトリが存在する"
  assert_dir_exists ".claude/plans" ".claude/plans/ ディレクトリが存在する"

  # hooks
  assert_file_exists ".claude/hooks/guardrails/worktree-guard.sh" "worktree-guard.sh が存在する"
  assert_file_executable ".claude/hooks/guardrails/worktree-guard.sh" "worktree-guard.sh に実行権限がある"
  assert_file_exists ".claude/hooks/guardrails/commit-guard.sh" "commit-guard.sh が存在する"
  assert_file_executable ".claude/hooks/guardrails/commit-guard.sh" "commit-guard.sh に実行権限がある"
  assert_file_exists ".claude/hooks/guardrails/gh-guard.sh" "gh-guard.sh が存在する"
  assert_file_executable ".claude/hooks/guardrails/gh-guard.sh" "gh-guard.sh に実行権限がある"

  # skills
  assert_file_exists ".claude/skills/git-worktrees/SKILL.md" "git-worktrees skill が存在する"

  # .gitignore
  assert_gitignore_contains ".worktrees/" ".gitignore に .worktrees/ がある"
  assert_gitignore_contains ".local-docs/" ".gitignore に .local-docs/ がある"
  assert_gitignore_contains ".claude/agent-memory-local/" ".gitignore に agent-memory-local がある"

  # --- vdd.config のフォーマット検証 ---
  echo ""
  info "vdd.config の設定値を検証しています..."
  if [ -f "$TARGET_DIR/.claude/vdd.config" ]; then
    # source してみて構文エラーがないか
    if bash -n "$TARGET_DIR/.claude/vdd.config" 2>/dev/null; then
      success "vdd.config の構文は正しい"
      ((PASS++))

      # プレースホルダーが残っていないか
      if grep -q '{{' "$TARGET_DIR/.claude/vdd.config" 2>/dev/null; then
        warn "vdd.config に未置換のプレースホルダーが残っています"
        ((WARN++))
      else
        success "vdd.config のプレースホルダーは全て置換済み"
        ((PASS++))
      fi
    else
      error "vdd.config に構文エラーがあります"
      ((FAIL++))
    fi
  fi

  # --- CLAUDE.md のプレースホルダー検証 ---
  if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
    if grep -q '{{' "$TARGET_DIR/CLAUDE.md" 2>/dev/null; then
      warn "CLAUDE.md に未置換のプレースホルダーが残っています"
      ((WARN++))
    else
      success "CLAUDE.md のプレースホルダーは全て置換済み"
      ((PASS++))
    fi
  fi

  # --- settings.json の hook パス整合性 ---
  echo ""
  info "settings.json の hook パスを検証しています..."
  if [ -f "$TARGET_DIR/.claude/settings.json" ]; then
    local hook_commands
    hook_commands=$(jq -r '.. | .command? // empty' "$TARGET_DIR/.claude/settings.json" 2>/dev/null | grep -v '^$')

    while IFS= read -r cmd; do
      [ -z "$cmd" ] && continue
      # $CLAUDE_PROJECT_DIR を TARGET_DIR に置換して実在チェック
      local resolved
      resolved=$(echo "$cmd" | sed "s|\\\$CLAUDE_PROJECT_DIR|$TARGET_DIR|g" | sed 's/^bash //')
      if [ -f "$resolved" ]; then
        success "hook パスが有効: $(basename "$resolved")"
        ((PASS++))
      else
        error "hook パスが無効: $cmd"
        ((FAIL++))
      fi
    done <<< "$hook_commands"
  fi

  # --- Level 2 以上の検証 ---
  if [ "$level" -ge 2 ]; then
    echo ""
    header "Level 2: Structured Releases"
    assert_file_exists ".claude/hooks/rdd-reminder/remind.sh" "RDD reminder hook が存在する"
    assert_file_executable ".claude/hooks/rdd-reminder/remind.sh" "RDD reminder に実行権限がある"
    assert_file_exists ".claude/hooks/conversation-logger/log.sh" "conversation logger が存在する"
    assert_file_executable ".claude/hooks/conversation-logger/log.sh" "conversation logger に実行権限がある"
    assert_dir_exists ".claude/release-specs" "release-specs ディレクトリが存在する"
    assert_dir_exists ".claude/templates" "templates ディレクトリが存在する"
    assert_dir_exists "process" "process ディレクトリが存在する"
  fi

  # --- Level 3 以上の検証 ---
  if [ "$level" -ge 3 ]; then
    echo ""
    header "Level 3: Quality-Enforced"
    assert_file_exists ".claude/hooks/review-enforcement/check.sh" "review enforcement hook が存在する"
    assert_file_executable ".claude/hooks/review-enforcement/check.sh" "review enforcement に実行権限がある"
    assert_file_exists ".claude/hooks/subagent-rules/inject.sh" "subagent rules hook が存在する"
    assert_file_executable ".claude/hooks/subagent-rules/inject.sh" "subagent rules に実行権限がある"
    assert_file_exists ".claude/agents/code-reviewer.md" "code-reviewer agent が存在する"
    assert_file_exists ".claude/agents/implementer.md" "implementer agent が存在する"
    assert_file_exists ".claude/agents/release-manager.md" "release-manager agent が存在する"
    assert_dir_exists ".claude/agent-memory" "agent-memory ディレクトリが存在する"
    assert_dir_exists ".claude/design-logs" "design-logs ディレクトリが存在する"
  fi

  # --- Level 4 以上の検証 ---
  if [ "$level" -ge 4 ]; then
    echo ""
    header "Level 4: Vision-Aligned"
    assert_file_exists ".claude/vdd/VISION.md" "VISION.md が存在する"
    assert_file_exists ".claude/vdd/DECISIONS.md" "DECISIONS.md が存在する"
    assert_file_exists ".claude/vdd/DAILY_SCORE.md" "DAILY_SCORE.md が存在する"
    assert_file_exists ".claude/reviewer-profile.md" "reviewer-profile.md が存在する"
  fi

  # --- 結果サマリー ---
  echo ""
  header "検証結果"
  echo ""
  success "$PASS 件のチェックに合格"
  if [ "$WARN" -gt 0 ]; then
    warn "$WARN 件の警告"
  fi
  if [ "$FAIL" -gt 0 ]; then
    error "$FAIL 件のチェックに失敗"
    echo ""
    exit 1
  else
    echo ""
    success "全ての検証に合格しました"
  fi
}

# ===========================
# エントリーポイント
# ===========================

main "$@"
