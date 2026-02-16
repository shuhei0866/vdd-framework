# /worktree-clean

git worktree を整理するコマンド。不要な worktree を削除し、リポジトリを綺麗に保つ。

## 実行内容

1. 現在の worktree 一覧を確認
2. 無効な worktree を自動削除（prune）
3. 削除対象の worktree を確認して削除

## 手順

### 1. 現在の worktree 一覧を確認

```bash
git worktree list
```

### 2. 無効な worktree を自動削除

```bash
git worktree prune
```

存在しないディレクトリを参照している worktree エントリを削除する。

### 3. 特定の worktree を削除

```bash
# 通常の削除（変更がある場合は失敗）
git worktree remove <worktree-path>

# 強制削除（変更があっても削除）
git worktree remove --force <worktree-path>
```

### 4. 関連するリモートブランチも削除する場合

```bash
# worktree を削除後、ブランチも削除
git branch -d <branch-name>

# 強制削除
git branch -D <branch-name>

# リモートブランチも削除
git push origin --delete <branch-name>
```

## 一括クリーンアップ

マージ済みの worktree を一括で削除する場合：

```bash
# 1. prune で無効なエントリを削除
git worktree prune

# 2. 一覧を確認
git worktree list

# 3. 不要なものを個別に削除
git worktree remove <path>
```

## 注意事項

- メインのワーキングディレクトリは削除できない
- 未コミットの変更がある worktree は `--force` が必要
- worktree を削除しても関連ブランチは残る（必要に応じて別途削除）
