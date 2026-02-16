#!/bin/bash
# template.sh - VDD Framework テンプレート置換ユーティリティ
# {{PLACEHOLDER}} パターンをファイル内で置換する。

# === プレースホルダー置換（単一ファイル） ===
# 引数: ファイルパス, キー, 値
# macOS (BSD sed) と Linux (GNU sed) の両方に対応
substitute_template() {
  local file="$1"
  local key="$2"
  local value="$3"

  if [ ! -f "$file" ]; then
    return 1
  fi

  # sed -i の macOS/Linux 互換処理
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s|{{${key}}}|${value}|g" "$file"
  else
    sed -i "s|{{${key}}}|${value}|g" "$file"
  fi
}

# === ディレクトリ配下の全テンプレートファイルを置換 ===
# 引数: ディレクトリパス, key=value ペア（複数可）
# 例: process_templates ./output PROJECT_NAME=myapp TEST_COMMAND="pnpm test"
process_templates() {
  local dir="$1"
  shift

  if [ ! -d "$dir" ]; then
    return 1
  fi

  # テンプレートファイルを検索（バイナリを除外）
  local files
  files=$(find "$dir" -type f \( -name "*.md" -o -name "*.json" -o -name "*.sh" -o -name "vdd.config" -o -name "*.template" \) 2>/dev/null)

  for pair in "$@"; do
    local key="${pair%%=*}"
    local value="${pair#*=}"

    while IFS= read -r file; do
      [ -z "$file" ] && continue
      substitute_template "$file" "$key" "$value"
    done <<< "$files"
  done
}

# === .template 拡張子を除去してリネーム ===
# 引数: ファイルパス (.template 付き)
# 例: rename_template ./output/CLAUDE.md.template → ./output/CLAUDE.md
rename_template() {
  local file="$1"

  if [[ "$file" == *.template ]]; then
    local target="${file%.template}"
    mv "$file" "$target"
    echo "$target"
  else
    echo "$file"
  fi
}
