#!/bin/bash
# conversation-logger: SessionEnd 時に対話ログを .local-docs/sessions/ に保存する
# LLM 呼び出しなし。決定論的なシェルスクリプトのみ。

set -uo pipefail

# stdin から JSON を読み取る
INPUT=$(cat)

# jq の存在チェック
HAS_JQ=false
if command -v jq &>/dev/null; then
  HAS_JQ=true
fi

# session_id と transcript_path を取得
if [ "$HAS_JQ" = true ]; then
  SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
  TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
else
  SESSION_ID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | sed 's/"session_id":"//;s/"//')
  TRANSCRIPT_PATH=$(echo "$INPUT" | grep -o '"transcript_path":"[^"]*"' | sed 's/"transcript_path":"//;s/"//')
fi

# 必須フィールドの検証
if [ -z "${SESSION_ID:-}" ] || [ -z "${TRANSCRIPT_PATH:-}" ]; then
  exit 0
fi

if [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# プロジェクトルートを特定
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"
SESSIONS_DIR="$PROJECT_DIR/.local-docs/sessions"

# 出力ディレクトリの作成
DATE=$(date +%Y-%m-%d)
SESSION_SHORT=$(echo "$SESSION_ID" | head -c 8)
OUTPUT_DIR="$SESSIONS_DIR/${DATE}_${SESSION_SHORT}"
mkdir -p "$OUTPUT_DIR"

# 1. 原文 JSONL をコピー（完全性担保）
cp "$TRANSCRIPT_PATH" "$OUTPUT_DIR/transcript.jsonl"

# 2. 読みやすい Markdown に変換（jq が利用可能な場合）
if command -v jq &>/dev/null; then
  {
    echo "# Session Log"
    echo ""
    echo "**Session ID**: $SESSION_ID"
    echo "**Date**: $DATE"
    echo ""
    echo "---"
    echo ""

    while IFS= read -r line; do
      TYPE=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)

      case "$TYPE" in
        "human"|"user")
          MESSAGE=$(echo "$line" | jq -r '
            if .message then
              if (.message | type) == "string" then .message
              elif (.message | type) == "array" then
                [.message[] | select(.type == "text") | .text] | join("\n")
              else .message | tostring
              end
            elif .content then
              if (.content | type) == "string" then .content
              elif (.content | type) == "array" then
                [.content[] | select(.type == "text") | .text] | join("\n")
              else .content | tostring
              end
            else empty
            end
          ' 2>/dev/null)
          if [ -n "$MESSAGE" ]; then
            echo "## Human"
            echo ""
            echo "$MESSAGE"
            echo ""
            echo "---"
            echo ""
          fi
          ;;
        "assistant")
          MESSAGE=$(echo "$line" | jq -r '
            if .message then
              if (.message | type) == "string" then .message
              elif (.message | type) == "array" then
                [.message[] | select(.type == "text") | .text] | join("\n")
              else .message | tostring
              end
            elif .content then
              if (.content | type) == "string" then .content
              elif (.content | type) == "array" then
                [.content[] | select(.type == "text") | .text] | join("\n")
              else .content | tostring
              end
            else empty
            end
          ' 2>/dev/null)
          if [ -n "$MESSAGE" ]; then
            echo "## Assistant"
            echo ""
            echo "$MESSAGE"
            echo ""
            echo "---"
            echo ""
          fi
          ;;
      esac
    done < "$TRANSCRIPT_PATH"
  } > "$OUTPUT_DIR/transcript.md"
fi

exit 0
