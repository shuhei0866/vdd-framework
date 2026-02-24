#!/bin/bash
# gh-guard.sh extract_pr_number 関数のテスト
#
# extract_pr_number を source して直接テストする。
# --body 等のフラグ引数内の数字を PR 番号として誤検出しないことを確認する。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GUARD_SCRIPT="$SCRIPT_DIR/../../template/.claude/hooks/guardrails/gh-guard.sh"
PASS=0
FAIL=0

# extract_pr_number 関数だけを source するために、関数部分を抽出
# (スクリプト全体を source すると stdin 読み込みでハングするため)
eval "$(sed -n '/^extract_pr_number()/,/^}/p' "$GUARD_SCRIPT")"

assert_eq() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $test_name (expected='$expected', actual='$actual')"
    FAIL=$((FAIL + 1))
  fi
}

# --- extract_pr_number テスト ---

# Case 1: --body 内の数字を PR 番号として拾わないこと
result=$(extract_pr_number 'gh pr review --approve --body "LGTM #123"' "review")
assert_eq "gh pr review --approve --body 'LGTM #123' => 空" "" "$result"

# Case 2: positional argument の PR 番号を正しく抽出
result=$(extract_pr_number 'gh pr review 456 --approve --body "LGTM #123"' "review")
assert_eq "gh pr review 456 --approve --body 'LGTM #123' => 456" "456" "$result"

# Case 3: gh pr merge の PR 番号抽出
result=$(extract_pr_number 'gh pr merge 789 --squash' "merge")
assert_eq "gh pr merge 789 --squash => 789" "789" "$result"

# Case 4: PR 番号なしの approve
result=$(extract_pr_number 'gh pr review --approve' "review")
assert_eq "gh pr review --approve => 空" "" "$result"

# Case 5: --body-file 引数内の数字を無視
result=$(extract_pr_number 'gh pr review 100 --approve --body-file /tmp/review-42.txt' "review")
assert_eq "gh pr review 100 --approve --body-file path => 100" "100" "$result"

# Case 6: シングルクォート内の数字を無視
result=$(extract_pr_number "gh pr merge 555 --squash --subject 'fix #999 and #888'" "merge")
assert_eq "gh pr merge 555 --subject 'fix #999' => 555" "555" "$result"

# Case 7: --body with HEREDOC style (quoted multiline)
result=$(extract_pr_number 'gh pr review 200 --approve --body "Reviewed PR #300 changes look good"' "review")
assert_eq "gh pr review 200 --body 'Reviewed PR #300...' => 200" "200" "$result"

# Case 8: -R repo フラグの値を無視
result=$(extract_pr_number 'gh pr merge 321 --squash -R owner/repo123' "merge")
assert_eq "gh pr merge 321 -R owner/repo123 => 321" "321" "$result"

# Case 9: ダブルクォート付き PR 番号
result=$(extract_pr_number 'gh pr merge "123" --squash' "merge")
assert_eq 'gh pr merge "123" --squash => 123' "123" "$result"

# Case 10: シングルクォート付き PR 番号
result=$(extract_pr_number "gh pr review '456' --approve" "review")
assert_eq "gh pr review '456' --approve => 456" "456" "$result"

echo ""
echo "---"
echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
