# /ship-to-develop

release/* ブランチの実装・レビュー完了後、統合ブランチ（develop）へのマージまでを実行するスキル。

## 前提条件

- 現在のブランチが `release/*` であること
- Phase 3（自己評価 + 独立レビュー）が完了していること
- 全てのチェック（型チェック、lint、テスト）が通過していること

## 実行フロー

### 1. PR 作成

```bash
# 統合ブランチに向けて PR を作成
git push -u origin HEAD
gh pr create --base develop --title "<PR タイトル>" --body-file <body-file>
```

**注意**: `--body` ではなく `--body-file` を使用すること。PR body にコマンド例や図解が含まれると、PreToolUse フックのパターンマッチで誤検出される可能性がある。

### 2. レビュアー承認の確認

PR のレビュアー（人間または AI レビュアー）の承認を確認する。

```bash
# PR の承認状態を確認
gh pr view <PR番号> --json reviews --jq '.reviews[] | select(.state == "APPROVED")'
```

承認待ちの場合はポーリングする。適切な間隔（60秒推奨）を空けること。

### 3. マージ実行

```bash
# squash マージ（通常）
gh pr merge <PR番号> --squash

# merge コミット（develop 同期など squash 不可の場合）
gh pr merge <PR番号> --merge
```

### 4. コンフリクト解消

マージ時にコンフリクトが発生した場合:

```bash
# 統合ブランチの最新を取り込む
git fetch origin develop
git rebase origin/develop

# コンフリクトを解消してプッシュ
git push --force-with-lease
```

その後、レビュアーの再承認を待ってからマージする。

## 注意事項

- このスキルは**道具**であり、使うかどうかはエージェントの判断に委ねられる
- Stop フック（release-completion/check.sh）が完了条件を検証するため、このスキルを使わなくても完了条件を満たせばゲートを通過できる
- `--body-file` パターンの使用は、commit-guard の検査境界問題（コマンド引数の誤検出）を回避するため
