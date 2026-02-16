---
name: release-ready
description: release/* ブランチの実装完了後、PR 作成前のセルフチェック時、または /release-ready と呼ばれた時に使用する。テスト・レビュー・リスク評価を一括実行する。
context: fork
agent: code-reviewer
---

# リリース準備評価

リリースブランチの実装完了後、人間の QA 前に品質評価を実行してください。

## 前提条件

- 現在のブランチが `release/*` であること
- リリース仕様書（`.claude/release-specs/{release-name}.md`）がブランチ名に対応するパスに存在すること

## 手順

### 1. メモリの確認

エージェントメモリを確認し、過去のリリースレビューで発見したパターンを思い出す。

### 2. 環境確認

```bash
BRANCH=$(git branch --show-current)
if [[ ! "$BRANCH" =~ ^release/ ]]; then
  echo "エラー: release/* ブランチではありません: $BRANCH"
  exit 1
fi

RELEASE_NAME="${BRANCH#release/}"
SPEC_PATH=".claude/release-specs/${RELEASE_NAME}.md"
if [ ! -f "$SPEC_PATH" ]; then
  echo "エラー: ${SPEC_PATH} が見つかりません"
  exit 1
fi
```

### 3. リリース仕様書を読み込む

リリース仕様書の内容を読み、期待される動作とスコープを把握する。

### 4. 自動チェックの実行

```bash
{{CHECK_COMMAND}}
```

結果を記録する（PASS/FAIL、テスト件数、エラー内容）。

### 5. 変更内容の分析

```bash
git diff main...HEAD --stat
git log main..HEAD --oneline
git diff main...HEAD --shortstat
```

### 6. リスク自動分類

変更ファイルのパスに基づいてリスクを分類する。プロジェクトのディレクトリ構成に応じて、以下のようなカテゴリで評価する:

| 変更パス | リスクカテゴリ | 重要度 |
|---------|-------------|--------|
| DB マイグレーション | データベース変更 | High |
| 認証・ミドルウェア | 認証フロー | High |
| 共有型定義 | API 契約 | Medium |
| API エンドポイント | API エンドポイント | Medium |
| UI コンポーネント | UI コンポーネント | Low |

### 7. コードレビュー

main からの差分を取得し、code-reviewer としてフルレビューを実施する。

```bash
git diff main...HEAD
```

### 8. テストカバレッジの評価

**自動テストでカバー済み:**
- ユニットテストが存在するビジネスロジック
- `{{CHECK_COMMAND}}` で検証されるもの

**手動 QA が必要:**
- UI の見た目・レイアウトの変更
- ユーザーインタラクション（クリック、フォーム送信、ナビゲーション）
- モバイル表示

### 9. レポートの生成

以下のフォーマットでレポートを生成する。**図解は必須**（Mermaid チャート推奨）。

```markdown
## リリース準備レポート

**ブランチ**: release/<name>
**日時**: YYYY-MM-DD HH:MM

### 図解
<!-- 変更の全体像、データフロー、状態遷移等を Mermaid で -->

### 自動チェック結果
- チェックコマンド: PASS/FAIL
  - 型チェック: PASS/FAIL
  - Lint: PASS/FAIL
  - テスト: X passing, Y failing

### コードレビュー結果
[Critical Issues / Suggestions / Good Points]

### 変更サマリー
- ファイル変更: N files (+X, -Y)
- コミット数: N commits

### リスク評価
- **レベル**: Low / Medium / High
- **根拠**: リスク要因の列挙

### 手動 QA チェックポイント
プレビュー環境で以下を確認してください：
1. 確認項目

### リリース仕様書との整合性
- 仕様書に記載された期待動作と実装の一致度
- スコープ外の変更が含まれていないか
```

### 10. メモリの更新

リリースレビューで新しい知見を発見した場合、メモリに記録する。
