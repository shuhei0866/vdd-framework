# CLAUDE.md

このファイルは、本リポジトリでコードを記述する際の Claude Code へのガイドラインです。

## プロジェクト概要

<!-- プロジェクトの概要を記述してください -->

## ワークツリー必須ルール `[L5: フック強制]`

**コードの変更は必ず git worktree 上で行うこと。メインワークツリー（リポジトリルート）では絶対にファイルを編集しない。**

> `worktree-guard.sh` (PreToolUse フック) がメインワークツリーでの Write/Edit を deny でブロックする。
> `commit-guard.sh` (PreToolUse フック) がメインワークツリーでの checkout/switch/stash pop を deny でブロックする。

- メインワークツリーでのブランチ切り替え（`git checkout`）禁止
- メインワークツリーでの `git checkout -- <file>`（変更の破棄）禁止
- メインワークツリーでの `git stash pop`（stash の適用）禁止
- コード変更が必要な場合は、まず `git worktree add .worktrees/<name> -b <branch>` でワークツリーを作成し、そのワークツリー内で作業する
- メインワークツリーは読み取り専用として扱い、調査・閲覧のみ行う

**理由:** メインワークツリーには他のブランチの未コミット作業が残っている場合があり、ブランチ切り替えや変更の破棄で未コミットの作業を消失させるリスクがある。

### コミット衛生 `[L5: フック強制]`

> `commit-guard.sh` (PreToolUse フック) が以下を deny でブロックする。

- `--no-verify` によるフックスキップは禁止
- `main` / `master` への `--force` push は禁止
- `develop` ブランチの削除は禁止

## Claude Code Hooks

| フック | イベント | 強制レベル | 説明 |
|--------|----------|-----------|------|
| `guardrails/worktree-guard.sh` | PreToolUse (Write\|Edit) | L5: deny | メインワークツリーでのファイル編集をブロック |
| `guardrails/commit-guard.sh` | PreToolUse (Bash) | L5: deny | 危険な git 操作をブロック |
