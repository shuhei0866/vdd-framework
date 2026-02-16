#!/bin/bash
# init.sh - VDD Framework 対話的セットアップウィザード
#
# 使い方:
#   bash /path/to/vdd-framework/scripts/init.sh
#
# 対象プロジェクトのルートディレクトリで実行すること。
# VDD Framework のテンプレートを元に、プロジェクトに Claude Code の
# ガードレール、スキル、エージェントを導入する。

set -euo pipefail

# スクリプト自身のディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$FRAMEWORK_ROOT/template"
TARGET_DIR="$(pwd)"

# ライブラリ読み込み
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/template.sh"

# ===========================
# メイン処理
# ===========================

main() {
  header "VDD Framework セットアップウィザード"
  echo ""

  # --- 前提条件チェック ---
  info "前提条件を確認しています..."
  if ! check_prerequisites; then
    exit 1
  fi
  success "前提条件を確認しました"

  # --- git リポジトリ確認 ---
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    error "git リポジトリ内で実行してください。"
    echo "  git init を実行してからセットアップしてください。"
    exit 1
  fi
  success "git リポジトリを検出しました"

  # --- 既存設定の確認 ---
  if [ -f "$TARGET_DIR/.claude/vdd.config" ]; then
    warn "既存の VDD 設定が検出されました (.claude/vdd.config)"
    echo -n "  上書きしますか? (y/N): "
    read -r overwrite
    if [[ ! "$overwrite" =~ ^[yY]$ ]]; then
      info "セットアップを中止しました。"
      exit 0
    fi
  fi

  # --- プロジェクトタイプ自動検出 ---
  header "1. プロジェクト情報"
  local project_type
  project_type=$(detect_project_type "$TARGET_DIR")
  local project_type_name
  project_type_name=$(project_type_label "$project_type")

  if [ "$project_type" != "unknown" ]; then
    success "プロジェクトタイプを検出しました: $project_type_name"
  else
    warn "プロジェクトタイプを自動検出できませんでした。"
  fi

  # --- 対話的入力 ---
  local dir_name
  dir_name=$(basename "$TARGET_DIR")

  echo ""
  echo -n "  プロジェクト名 [$dir_name]: "
  read -r project_name
  project_name="${project_name:-$dir_name}"

  local default_test default_check default_build default_install default_test_pattern
  default_test=$(default_command_for "$project_type" "test")
  default_check=$(default_command_for "$project_type" "check")
  default_build=$(default_command_for "$project_type" "build")
  default_install=$(default_command_for "$project_type" "install")
  default_test_pattern=$(default_command_for "$project_type" "test_pattern")

  echo -n "  テストコマンド [${default_test:-未設定}]: "
  read -r test_command
  test_command="${test_command:-$default_test}"

  echo -n "  チェックコマンド (テスト + lint) [${default_check:-未設定}]: "
  read -r check_command
  check_command="${check_command:-$default_check}"

  echo -n "  ビルドコマンド [${default_build:-未設定}]: "
  read -r build_command
  build_command="${build_command:-$default_build}"

  echo -n "  インストールコマンド [${default_install:-未設定}]: "
  read -r install_command
  install_command="${install_command:-$default_install}"

  echo -n "  テストファイルパターン [${default_test_pattern:-未設定}]: "
  read -r test_file_pattern
  test_file_pattern="${test_file_pattern:-$default_test_pattern}"

  # --- 採用レベル選択 ---
  header "2. 採用レベルの選択"
  echo ""
  echo "  VDD Framework の採用レベルを選択してください:"
  echo ""
  echo -e "  ${BOLD}[1] Safe Development${NC}"
  echo "      - worktree-guard (メインWT編集ブロック)"
  echo "      - commit-guard (危険な git 操作ブロック)"
  echo "      - gh-guard (PR 操作ガード)"
  echo "      - git-worktrees skill"
  echo ""
  echo -e "  ${BOLD}[2] Structured Releases${NC}"
  echo "      - Level 1 の全て"
  echo "      - RDD reminder"
  echo "      - Release spec template"
  echo "      - Precheck command"
  echo "      - Conversation logger"
  echo ""
  echo -e "  ${BOLD}[3] Quality-Enforced${NC}"
  echo "      - Level 2 の全て"
  echo "      - Agents (code-reviewer, implementer, release-manager)"
  echo "      - TDD skill + rules"
  echo "      - Review enforcement"
  echo "      - Subagent rules injection"
  echo "      - 8 skills (review, release, task-decompose, dig 等)"
  echo ""
  echo -e "  ${BOLD}[4] Vision-Aligned${NC}"
  echo "      - Level 3 の全て"
  echo "      - VDD artifacts (VISION.md, DECISIONS.md, DAILY_SCORE.md)"
  echo "      - Decision authority matrix"
  echo "      - Reviewer profile"
  echo ""
  echo -e "  ${BOLD}[5] Full Autonomous${NC}"
  echo "      - Level 4 の全て"
  echo "      - Cloud execution setup"
  echo "      - Debate partner integration"
  echo ""
  echo -n "  レベルを選択 [1-5] (デフォルト: 1): "
  read -r level
  level="${level:-1}"

  if [[ ! "$level" =~ ^[1-5]$ ]]; then
    error "無効なレベルです: $level"
    exit 1
  fi

  # --- 確認 ---
  header "3. 確認"
  echo ""
  echo "  プロジェクト名:       $project_name"
  echo "  プロジェクトタイプ:   $project_type_name"
  echo "  テストコマンド:       ${test_command:-未設定}"
  echo "  チェックコマンド:     ${check_command:-未設定}"
  echo "  ビルドコマンド:       ${build_command:-未設定}"
  echo "  インストールコマンド: ${install_command:-未設定}"
  echo "  テストパターン:       ${test_file_pattern:-未設定}"
  echo "  採用レベル:           $level"
  echo ""
  echo -n "  この設定でセットアップしますか? (Y/n): "
  read -r confirm
  if [[ "$confirm" =~ ^[nN]$ ]]; then
    info "セットアップを中止しました。"
    exit 0
  fi

  # --- ファイルコピー + 設定 ---
  header "4. ファイルのセットアップ"
  echo ""

  copy_level_files "$level"

  # --- プレースホルダー置換 ---
  info "設定値をテンプレートに反映しています..."
  process_templates "$TARGET_DIR/.claude" \
    "PROJECT_NAME=$project_name" \
    "TEST_COMMAND=$test_command" \
    "CHECK_COMMAND=$check_command" \
    "BUILD_COMMAND=$build_command" \
    "INSTALL_COMMAND=$install_command" \
    "TEST_FILE_PATTERN=$test_file_pattern"

  # CLAUDE.md.template の置換とリネーム
  if [ -f "$TARGET_DIR/CLAUDE.md.template" ]; then
    substitute_template "$TARGET_DIR/CLAUDE.md.template" "PROJECT_NAME" "$project_name"
    substitute_template "$TARGET_DIR/CLAUDE.md.template" "TEST_COMMAND" "$test_command"
    substitute_template "$TARGET_DIR/CLAUDE.md.template" "CHECK_COMMAND" "$check_command"
    substitute_template "$TARGET_DIR/CLAUDE.md.template" "BUILD_COMMAND" "$build_command"
    substitute_template "$TARGET_DIR/CLAUDE.md.template" "INSTALL_COMMAND" "$install_command"
    substitute_template "$TARGET_DIR/CLAUDE.md.template" "TEST_FILE_PATTERN" "$test_file_pattern"
    rename_template "$TARGET_DIR/CLAUDE.md.template"
    success "CLAUDE.md を生成しました"
  fi

  # --- .gitignore 追記 ---
  info ".gitignore を更新しています..."
  update_gitignore
  success ".gitignore を更新しました"

  # --- 実行権限の付与 ---
  info "hook スクリプトに実行権限を付与しています..."
  find "$TARGET_DIR/.claude/hooks" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
  success "実行権限を付与しました"

  # --- 完了メッセージ ---
  header "セットアップ完了"
  echo ""
  success "VDD Framework (Level $level) をセットアップしました"
  echo ""
  show_next_steps "$level"
}

# ===========================
# レベル別ファイルコピー
# ===========================

copy_level_files() {
  local level="$1"

  # Level 1: Safe Development（基本ガードレール）
  info "[Level 1] ガードレールをセットアップしています..."
  mkdir -p "$TARGET_DIR/.claude/hooks/guardrails"
  mkdir -p "$TARGET_DIR/.claude/plans"
  mkdir -p "$TARGET_DIR/.claude/skills/git-worktrees"
  mkdir -p "$TARGET_DIR/.worktrees"

  cp "$TEMPLATE_DIR/.claude/hooks/guardrails/worktree-guard.sh" "$TARGET_DIR/.claude/hooks/guardrails/"
  cp "$TEMPLATE_DIR/.claude/hooks/guardrails/commit-guard.sh" "$TARGET_DIR/.claude/hooks/guardrails/"
  cp "$TEMPLATE_DIR/.claude/hooks/guardrails/gh-guard.sh" "$TARGET_DIR/.claude/hooks/guardrails/"
  cp "$TEMPLATE_DIR/.claude/skills/git-worktrees/SKILL.md" "$TARGET_DIR/.claude/skills/git-worktrees/"
  cp "$TEMPLATE_DIR/.worktrees/.gitkeep" "$TARGET_DIR/.worktrees/"
  cp "$TEMPLATE_DIR/.claude/plans/.gitkeep" "$TARGET_DIR/.claude/plans/"

  # settings.json の生成（レベルに応じて構築）
  generate_settings_json "$level"

  # vdd.config のコピー
  cp "$TEMPLATE_DIR/.claude/vdd.config" "$TARGET_DIR/.claude/vdd.config"

  # CLAUDE.md.template のコピー
  if [ ! -f "$TARGET_DIR/CLAUDE.md" ]; then
    cp "$TEMPLATE_DIR/CLAUDE.md.template" "$TARGET_DIR/CLAUDE.md.template"
  fi

  success "Level 1: Safe Development をセットアップしました"

  [ "$level" -lt 2 ] && return 0

  # Level 2: Structured Releases
  info "[Level 2] リリース構造をセットアップしています..."
  mkdir -p "$TARGET_DIR/.claude/hooks/rdd-reminder"
  mkdir -p "$TARGET_DIR/.claude/hooks/conversation-logger"
  mkdir -p "$TARGET_DIR/.claude/release-specs"
  mkdir -p "$TARGET_DIR/.claude/templates"
  mkdir -p "$TARGET_DIR/.claude/commands"
  mkdir -p "$TARGET_DIR/.local-docs/sessions"
  mkdir -p "$TARGET_DIR/process"

  cp "$TEMPLATE_DIR/.claude/hooks/rdd-reminder/remind.sh" "$TARGET_DIR/.claude/hooks/rdd-reminder/"
  cp "$TEMPLATE_DIR/.claude/hooks/conversation-logger/log.sh" "$TARGET_DIR/.claude/hooks/conversation-logger/"
  cp "$TEMPLATE_DIR/.claude/release-specs/.gitkeep" "$TARGET_DIR/.claude/release-specs/"
  cp "$TEMPLATE_DIR/.claude/templates/release-spec.md" "$TARGET_DIR/.claude/templates/"
  cp "$TEMPLATE_DIR/.claude/commands/precheck.md" "$TARGET_DIR/.claude/commands/"
  cp "$TEMPLATE_DIR/.local-docs/sessions/.gitkeep" "$TARGET_DIR/.local-docs/sessions/"
  cp "$TEMPLATE_DIR/process/RDD.md" "$TARGET_DIR/process/"
  cp "$TEMPLATE_DIR/process/README.md" "$TARGET_DIR/process/"

  success "Level 2: Structured Releases をセットアップしました"

  [ "$level" -lt 3 ] && return 0

  # Level 3: Quality-Enforced
  info "[Level 3] 品質管理をセットアップしています..."
  mkdir -p "$TARGET_DIR/.claude/hooks/review-enforcement"
  mkdir -p "$TARGET_DIR/.claude/hooks/subagent-rules"
  mkdir -p "$TARGET_DIR/.claude/agents"
  mkdir -p "$TARGET_DIR/.claude/agent-memory/code-reviewer"
  mkdir -p "$TARGET_DIR/.claude/agent-memory/implementer"
  mkdir -p "$TARGET_DIR/.claude/agent-memory/release-manager"
  mkdir -p "$TARGET_DIR/.claude/design-logs"

  # Hooks
  cp "$TEMPLATE_DIR/.claude/hooks/review-enforcement/check.sh" "$TARGET_DIR/.claude/hooks/review-enforcement/"
  cp "$TEMPLATE_DIR/.claude/hooks/subagent-rules/inject.sh" "$TARGET_DIR/.claude/hooks/subagent-rules/"

  # Agents
  cp "$TEMPLATE_DIR/.claude/agents/code-reviewer.md" "$TARGET_DIR/.claude/agents/"
  cp "$TEMPLATE_DIR/.claude/agents/implementer.md" "$TARGET_DIR/.claude/agents/"
  cp "$TEMPLATE_DIR/.claude/agents/release-manager.md" "$TARGET_DIR/.claude/agents/"

  # Agent memory
  cp "$TEMPLATE_DIR/.claude/agent-memory/code-reviewer/MEMORY.md" "$TARGET_DIR/.claude/agent-memory/code-reviewer/"
  cp "$TEMPLATE_DIR/.claude/agent-memory/implementer/MEMORY.md" "$TARGET_DIR/.claude/agent-memory/implementer/"
  cp "$TEMPLATE_DIR/.claude/agent-memory/release-manager/MEMORY.md" "$TARGET_DIR/.claude/agent-memory/release-manager/"

  # Skills (8 skills)
  local skills=("review-now" "review-pr" "release-ready" "release" "task-decompose" "tdd" "dig" "security-balance" "env-secrets")
  for skill in "${skills[@]}"; do
    mkdir -p "$TARGET_DIR/.claude/skills/$skill"
    cp "$TEMPLATE_DIR/.claude/skills/$skill/skill.md" "$TARGET_DIR/.claude/skills/$skill/" 2>/dev/null || \
    cp "$TEMPLATE_DIR/.claude/skills/$skill/SKILL.md" "$TARGET_DIR/.claude/skills/$skill/" 2>/dev/null || true
  done

  # Commands
  cp "$TEMPLATE_DIR/.claude/commands/worktree-clean.md" "$TARGET_DIR/.claude/commands/" 2>/dev/null || true

  # Design logs
  cp "$TEMPLATE_DIR/.claude/design-logs/.gitkeep" "$TARGET_DIR/.claude/design-logs/"

  success "Level 3: Quality-Enforced をセットアップしました"

  [ "$level" -lt 4 ] && return 0

  # Level 4: Vision-Aligned
  info "[Level 4] ビジョン統合をセットアップしています..."
  mkdir -p "$TARGET_DIR/.claude/vdd"

  cp "$TEMPLATE_DIR/.claude/vdd/VISION.md" "$TARGET_DIR/.claude/vdd/"
  cp "$TEMPLATE_DIR/.claude/vdd/DECISIONS.md" "$TARGET_DIR/.claude/vdd/"
  cp "$TEMPLATE_DIR/.claude/vdd/DAILY_SCORE.md" "$TARGET_DIR/.claude/vdd/"
  cp "$TEMPLATE_DIR/.claude/vdd/README.md" "$TARGET_DIR/.claude/vdd/"
  cp "$TEMPLATE_DIR/.claude/reviewer-profile.md" "$TARGET_DIR/.claude/"
  cp "$TEMPLATE_DIR/process/VDD.md" "$TARGET_DIR/process/"

  success "Level 4: Vision-Aligned をセットアップしました"

  [ "$level" -lt 5 ] && return 0

  # Level 5: Full Autonomous
  info "[Level 5] 自律実行をセットアップしています..."
  # cloud-execution.md やその他の設定をコピー
  # 現時点ではテンプレートに存在するファイルのみ
  success "Level 5: Full Autonomous をセットアップしました"
}

# ===========================
# settings.json の生成
# ===========================

generate_settings_json() {
  local level="$1"
  local settings_file="$TARGET_DIR/.claude/settings.json"

  # hooks を段階的に構築
  local hooks_json=""

  # Level 1: 基本ガードレール
  hooks_json=$(cat << 'LEVEL1'
{
  "permissions": {
    "deny": []
  },
  "plansDirectory": "./.claude/plans",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/guardrails/worktree-guard.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/guardrails/commit-guard.sh"
          },
          {
            "type": "command",
            "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/guardrails/gh-guard.sh"
          }
        ]
      }
    ]
  }
}
LEVEL1
)

  if [ "$level" -ge 2 ]; then
    # Level 2: RDD reminder + conversation logger
    hooks_json=$(echo "$hooks_json" | jq '
      .hooks.UserPromptSubmit = [{
        "hooks": [{
          "type": "command",
          "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/rdd-reminder/remind.sh"
        }]
      }] |
      .hooks.SessionEnd = [{
        "hooks": [{
          "type": "command",
          "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/conversation-logger/log.sh",
          "async": true
        }]
      }]
    ')
  fi

  if [ "$level" -ge 3 ]; then
    # Level 3: subagent rules + review enforcement
    hooks_json=$(echo "$hooks_json" | jq '
      .hooks.SubagentStart = [{
        "hooks": [{
          "type": "command",
          "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/subagent-rules/inject.sh"
        }]
      }] |
      .hooks.Stop = [{
        "hooks": [{
          "type": "command",
          "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/review-enforcement/check.sh"
        }]
      }]
    ')
  fi

  echo "$hooks_json" | jq '.' > "$settings_file"
  success "settings.json を生成しました"
}

# ===========================
# .gitignore 更新
# ===========================

update_gitignore() {
  local gitignore="$TARGET_DIR/.gitignore"
  local additions="$TEMPLATE_DIR/.gitignore.additions"

  if [ ! -f "$additions" ]; then
    return 0
  fi

  # .gitignore がなければ作成
  touch "$gitignore"

  # 既に追記済みの行はスキップ
  while IFS= read -r line; do
    # コメント行と空行はスキップ
    if [[ "$line" =~ ^# ]] || [[ -z "$line" ]]; then
      continue
    fi

    if ! grep -qxF "$line" "$gitignore" 2>/dev/null; then
      echo "$line" >> "$gitignore"
    fi
  done < "$additions"
}

# ===========================
# 次のステップ表示
# ===========================

show_next_steps() {
  local level="$1"

  echo -e "  ${BOLD}次のステップ:${NC}"
  echo ""
  echo "  1. CLAUDE.md を編集してプロジェクト固有の情報を記入してください"
  echo "     - <!-- CUSTOMIZE --> マーカーのあるセクションを更新"
  echo "     - プロジェクト概要、技術スタック、アーキテクチャ等"
  echo ""
  echo "  2. .claude/vdd.config の設定値を確認してください"
  echo ""
  echo "  3. 設定をコミットしてください:"
  echo "     git add .claude/ CLAUDE.md .gitignore"
  if [ "$level" -ge 2 ]; then
    echo "     git add process/"
  fi
  echo "     git commit -m 'chore: setup VDD Framework (Level $level)'"
  echo ""

  if [ "$level" -ge 2 ]; then
    echo "  4. develop ブランチを作成してください:"
    echo "     git checkout -b develop"
    echo "     git push -u origin develop"
    echo ""
  fi

  echo "  検証:"
  echo "     bash $FRAMEWORK_ROOT/scripts/validate.sh"
  echo ""
}

# ===========================
# エントリーポイント
# ===========================

main "$@"
