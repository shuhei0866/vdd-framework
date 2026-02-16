#!/bin/bash
# common.sh - VDD Framework 共通ユーティリティ
# スクリプト群から source して使用する。

# === 色定義 ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# === ログ関数 ===
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
header()  { echo -e "\n${BOLD}$1${NC}"; }

# === 前提条件チェック ===
# 必須: git, jq
# 任意: claude (Claude Code CLI)
check_prerequisites() {
  local missing=()

  if ! command -v git &>/dev/null; then
    missing+=("git")
  fi

  if ! command -v jq &>/dev/null; then
    missing+=("jq")
  fi

  if [ ${#missing[@]} -gt 0 ]; then
    error "以下のツールがインストールされていません: ${missing[*]}"
    echo "  インストール後に再度実行してください。"
    return 1
  fi

  if ! command -v claude &>/dev/null; then
    warn "Claude Code CLI が見つかりません。セットアップ後にインストールしてください。"
    warn "  https://docs.anthropic.com/en/docs/claude-code"
  fi

  return 0
}

# === プロジェクトタイプ自動検出 ===
# 引数: 対象ディレクトリ（省略時はカレント）
# 出力: プロジェクトタイプ文字列
detect_project_type() {
  local dir="${1:-.}"

  if [ -f "$dir/package.json" ]; then
    # パッケージマネージャーの検出
    if [ -f "$dir/pnpm-lock.yaml" ] || [ -f "$dir/pnpm-workspace.yaml" ]; then
      echo "node-pnpm"
    elif [ -f "$dir/yarn.lock" ]; then
      echo "node-yarn"
    elif [ -f "$dir/bun.lockb" ] || [ -f "$dir/bun.lock" ]; then
      echo "node-bun"
    else
      echo "node-npm"
    fi
  elif [ -f "$dir/pyproject.toml" ]; then
    echo "python-pyproject"
  elif [ -f "$dir/requirements.txt" ]; then
    echo "python-requirements"
  elif [ -f "$dir/Cargo.toml" ]; then
    echo "rust"
  elif [ -f "$dir/go.mod" ]; then
    echo "go"
  elif [ -f "$dir/Makefile" ] || [ -f "$dir/makefile" ]; then
    echo "make"
  else
    echo "unknown"
  fi
}

# === プロジェクトタイプからデフォルトコマンドを推定 ===
# 引数: プロジェクトタイプ, コマンド種別 (test|check|build|install)
# 出力: デフォルトコマンド文字列
default_command_for() {
  local project_type="$1"
  local cmd_type="$2"

  case "$project_type" in
    node-pnpm)
      case "$cmd_type" in
        test)    echo "pnpm test" ;;
        check)   echo "pnpm check" ;;
        build)   echo "pnpm build" ;;
        install) echo "pnpm install" ;;
        test_pattern) echo "*.test.{ts,tsx}" ;;
      esac
      ;;
    node-yarn)
      case "$cmd_type" in
        test)    echo "yarn test" ;;
        check)   echo "yarn check" ;;
        build)   echo "yarn build" ;;
        install) echo "yarn install" ;;
        test_pattern) echo "*.test.{ts,tsx}" ;;
      esac
      ;;
    node-bun)
      case "$cmd_type" in
        test)    echo "bun test" ;;
        check)   echo "bun run check" ;;
        build)   echo "bun run build" ;;
        install) echo "bun install" ;;
        test_pattern) echo "*.test.{ts,tsx}" ;;
      esac
      ;;
    node-npm)
      case "$cmd_type" in
        test)    echo "npm test" ;;
        check)   echo "npm run check" ;;
        build)   echo "npm run build" ;;
        install) echo "npm install" ;;
        test_pattern) echo "*.test.{ts,tsx}" ;;
      esac
      ;;
    python-pyproject|python-requirements)
      case "$cmd_type" in
        test)    echo "pytest" ;;
        check)   echo "pytest && ruff check ." ;;
        build)   echo "" ;;
        install)
          if [ "$project_type" = "python-pyproject" ]; then
            echo "pip install -e ."
          else
            echo "pip install -r requirements.txt"
          fi
          ;;
        test_pattern) echo "test_*.py" ;;
      esac
      ;;
    rust)
      case "$cmd_type" in
        test)    echo "cargo test" ;;
        check)   echo "cargo test && cargo clippy" ;;
        build)   echo "cargo build --release" ;;
        install) echo "" ;;
        test_pattern) echo "" ;;
      esac
      ;;
    go)
      case "$cmd_type" in
        test)    echo "go test ./..." ;;
        check)   echo "go test ./... && go vet ./..." ;;
        build)   echo "go build ./..." ;;
        install) echo "" ;;
        test_pattern) echo "*_test.go" ;;
      esac
      ;;
    make)
      case "$cmd_type" in
        test)    echo "make test" ;;
        check)   echo "make check" ;;
        build)   echo "make build" ;;
        install) echo "make install" ;;
        test_pattern) echo "" ;;
      esac
      ;;
    *)
      echo ""
      ;;
  esac
}

# === プロジェクトタイプの表示名 ===
project_type_label() {
  local project_type="$1"
  case "$project_type" in
    node-pnpm)             echo "Node.js (pnpm)" ;;
    node-yarn)             echo "Node.js (yarn)" ;;
    node-bun)              echo "Node.js (bun)" ;;
    node-npm)              echo "Node.js (npm)" ;;
    python-pyproject)      echo "Python (pyproject.toml)" ;;
    python-requirements)   echo "Python (requirements.txt)" ;;
    rust)                  echo "Rust (Cargo)" ;;
    go)                    echo "Go" ;;
    make)                  echo "Makefile" ;;
    *)                     echo "不明" ;;
  esac
}
