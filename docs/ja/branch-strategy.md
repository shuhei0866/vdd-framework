# 3層ブランチ戦略

## 概要

VDD の自律開発サイクルを安全に運用するためのブランチ戦略。本番（main）、統合（develop）、作業（release/*）の3層構造により、AI の自律実装が本番環境に直接影響することを防ぐ。

## 3層構造

```
main (production)     ← 人間が昇格トリガー（フィードバック会）
  ↑
develop (integration) ← 独立レビュアーが approve、実装エージェントがマージ
  ↑                     常設プレビュー環境
release/* (作業)      ← worktree で TDD 実装
```

### main（本番ブランチ）

- **役割**: 本番環境にデプロイされるブランチ
- **更新方法**: `develop` からの昇格のみ（人間がトリガー）
- **保護**: 直接コミット禁止、force push 禁止

### develop（統合ブランチ）

- **役割**: リリースブランチの統合先。プレビュー環境にデプロイ
- **更新方法**: `release/*` からのマージ（独立レビュアーの approve 後）
- **性質**: 永続ブランチ。削除しない

### release/*（作業ブランチ）

- **役割**: 個別リリースの実装作業
- **命名**: `release/<release-name>`（例: `release/user-notifications`）
- **作業環境**: 必ず worktree 上で作業（メインワークツリーでの編集は禁止）
- **ライフサイクル**: 作成 → 実装 → レビュー → マージ → 削除

## 運用ルール

### 1. develop は永続ブランチ

削除しない。main と同格の長命ブランチとして扱う。

### 2. マージ方向

```
release/* → develop   : 独立レビュアーの approve 後に実装エージェントが実行
develop  → main       : 人間がトリガー（フィードバック会）
main     → develop    : main に直接入った変更（hotfix 等）を同期
```

### 3. main への直接マージ禁止

`release/*` から `main` への直接マージは禁止。必ず `develop` を経由する。この制約は hook（L5: deny）で技術的に強制される。

### 4. 昇格後の同期

`develop → main` 昇格後、`develop` を `main` にリベースして同期する。

## ワークフロー

### リリースの実装からマージまで

```
1. worktree を作成
   git worktree add .worktrees/release-feature -b release/feature

2. worktree 内で TDD 実装
   cd .worktrees/release-feature
   # テストファースト → 実装 → リファクタリング

3. チェック通過を確認
   # プロジェクトのチェックコマンドを実行

4. レビューを実行
   # 自己評価 + 独立レビュー

5. PR を作成（develop 向け）
   gh pr create --base develop

6. 独立レビュアーの approve を待機
   gh pr view <PR番号> --json reviewDecision

7. approve 確認後マージ
   gh pr merge --squash

8. worktree を削除
   git worktree remove .worktrees/release-feature
```

### develop から main への昇格

```
1. フィードバック会で人間が判断
   - プレビュー環境で動作確認（Layer 3 QA）
   - ビジョンとの整合性確認

2. 昇格を実行
   git checkout main
   git merge develop
   git push origin main

3. develop を同期
   git checkout develop
   git rebase main
   git push origin develop
```

## 並列開発

複数のリリースを並列で進める場合、各リリースは独立した worktree で作業する。

```
repository/
├── .worktrees/
│   ├── release-feature-a/    # リリース A（worktree）
│   ├── release-feature-b/    # リリース B（worktree）
│   └── release-bugfix-c/     # リリース C（worktree）
```

### 並列開発時の注意

- 各リリースが編集するファイルが重複しないよう設計する
- 共有リソース（DB スキーマ、共通型定義等）の変更は単一のリリースに集約する
- 依存関係がある場合は順序を明示する（リリースツリーを使用）

## hook による強制

| hook | 強制レベル | 防止する操作 |
|------|-----------|-------------|
| `worktree-guard.sh` | L5: deny | メインワークツリーでのファイル編集 |
| `commit-guard.sh` | L5: deny | 保護ブランチへの直接コミット |
| `commit-guard.sh` | L5: deny | `release/*` → `main` への直接マージ |
| `commit-guard.sh` | L5: deny | `develop` ブランチの削除 |
| `commit-guard.sh` | L5: deny | メインワークツリーでの `git checkout`/`switch` |
| `commit-guard.sh` | L5: deny | `--no-verify` による hook スキップ |
| `commit-guard.sh` | L5: deny | `main` への force push |

## VDD イテレーションループとの関係

ブランチ戦略は QA の3層モデルと連動する:

```
release/* (worktree)
    │
    ├── Layer 1: 自動テスト
    ├── Layer 2: AI レビュー
    │
    ▼
develop (統合)
    │
    ├── Layer 3: 人間 QA（プレビュー環境）
    │
    ▼
main (本番)
```

- Layer 1 + 2 は `release/*` 上で AI が自律的に実施
- Layer 3 は `develop` のプレビュー環境で人間が実施
- 全 Layer 通過後に `main` へ昇格

## 関連ドキュメント

- [qa-layers.md](./qa-layers.md) — QA の3層モデル
- [RDD.md](./RDD.md) — リリースのフェーズ
- [enforcement-levels.md](./enforcement-levels.md) — hook の強制レベル
