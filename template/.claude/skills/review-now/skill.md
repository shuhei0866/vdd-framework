---
name: review-now
description: ローカルの未コミット変更をレビューしたい時、PR 作成前の品質チェック時、または /review-now と呼ばれた時に使用する。独立コンテキストで客観的なコードレビューを実行する。
context: fork
agent: code-reviewer
---

# ローカル変更レビュー

ローカルの変更を独立したコンテキストで客観的にレビューしてください。

## 手順

### 1. メモリの確認

エージェントメモリを確認し、過去のレビューで発見したパターンや頻出する問題を思い出す。

### 2. 変更内容の取得

```bash
# デフォルト: ステージング済み + 未ステージングの全変更
git diff HEAD --stat
git diff HEAD
```

引数で制御:
- `--staged`: ステージング済みの変更のみ (`git diff --cached`)
- `--file=<path>`: 特定ファイルの変更のみ (`git diff HEAD -- <path>`)
- `--focus=security|performance|all`: 特定の観点に絞る

$ARGUMENTS

### 3. レビュー実行

変更内容を以下の観点でレビューする:

#### セキュリティ (Critical)
- SQL インジェクション、XSS、コマンドインジェクション
- 認証・認可の不備
- 機密情報のハードコード

#### バグの可能性 (High)
- 境界値・エッジケースの未処理
- null/undefined の未チェック
- 非同期処理の競合状態
- エラーハンドリングの不備

#### パフォーマンス (Medium)
- N+1 クエリ
- 不要な再レンダリング・再計算

#### 可読性・保守性 (Medium)
- 複雑すぎるロジック
- 命名の不適切さ、重複コード

### 4. 結果の出力

レビュー結果を以下のフォーマットで出力:

```markdown
## Code Review Summary

### Critical Issues
- [ ] **[ファイル名:行番号]** 問題の説明

### Suggestions
- **[ファイル名:行番号]** 改善提案

### Good Points
- 良かった点

### Overall Assessment
総合評価と理由
```

### 5. メモリの更新

レビューで新しいパターンや知見を発見した場合、メモリに記録する。
