# ステップバイステップ採用ガイド

## 概要

VDD Framework をプロジェクトに導入するための手順を、ステップバイステップで説明する。最小限の安全装置（Level 1）から始めて、段階的にフレームワークの機能を有効化できる。

## 前提条件

| ツール | バージョン | 用途 |
|--------|-----------|------|
| git | 2.30+ | バージョン管理、worktree |
| Claude Code CLI | 最新版 | AI 自律開発 |
| jq | 1.6+ | 設定ファイルの処理 |
| bash | 4.0+ | hook スクリプト |

### Claude Code のインストール

```bash
npm install -g @anthropic-ai/claude-code
claude login
```

## Step 1: 初期化

### init.sh の実行

プロジェクトのルートディレクトリで初期化スクリプトを実行する。

```bash
# VDD Framework リポジトリをクローン（または直接ダウンロード）
git clone <vdd-framework-repo-url>

# 初期化スクリプトを実行
bash vdd-framework/scripts/init.sh
```

`init.sh` は対話的に以下を設定する:

1. **採用レベルの選択**: L1（Safe Development）から L5（Full Autonomous）まで
2. **ディレクトリ構造の作成**: `.claude/` 配下に必要なファイルを配置
3. **hook のインストール**: 選択したレベルに応じた hook を `.claude/hooks/` に配置
4. **settings.json の生成**: Claude Code の設定ファイルを生成
5. **CLAUDE.md テンプレートの配置**: プロジェクト固有にカスタマイズするためのテンプレート

### 生成されるディレクトリ構造

```
your-project/
├── .claude/
│   ├── hooks/
│   │   ├── guardrails/
│   │   │   ├── worktree-guard.sh    # L1: メインWT編集ブロック
│   │   │   └── commit-guard.sh      # L1: 危険なgit操作ブロック
│   │   ├── subagent-rules/
│   │   │   └── inject.sh            # L3: サブエージェントルール注入
│   │   └── review-enforcement/
│   │       └── check.sh             # L3: レビュー未実行ブロック
│   ├── settings.json
│   ├── release-specs/               # リリース仕様書の配置場所
│   ├── templates/
│   │   └── release-spec.md          # リリース仕様書テンプレート
│   ├── skills/                      # カスタムスキル
│   └── agents/                      # エージェント定義
├── vdd/                             # VDD アーティファクト（L4+）
│   ├── VISION.md
│   ├── DECISIONS.md
│   └── DAILY_SCORE.md
├── process/                         # プロセス仕様
│   ├── VDD.md
│   └── RDD.md
└── CLAUDE.md                        # プロジェクト固有の設定
```

## Step 2: CLAUDE.md のカスタマイズ

テンプレートから生成された `CLAUDE.md` をプロジェクトに合わせてカスタマイズする。

```bash
# テンプレートが配置されている
cat CLAUDE.md
```

最低限カスタマイズすべき項目:

1. **プロジェクト概要**: プロジェクトの説明
2. **技術スタック**: 使用しているフレームワーク、言語、ツール
3. **コマンド**: ビルド、テスト、lint 等のコマンド
4. **アーキテクチャ**: ディレクトリ構造と設計パターン

## Step 3: 最初のリリースサイクルの実践

### 3-1. リリース仕様書の作成

```bash
# テンプレートをコピー
cp .claude/templates/release-spec.md .claude/release-specs/my-first-feature.md
```

仕様書に以下を記載する:
- リリースで期待される動作
- スコープ外の明示
- リスク要因
- テスト戦略

### 3-2. worktree の作成

```bash
# リリースブランチ用の worktree を作成
git worktree add .worktrees/release-my-first-feature -b release/my-first-feature
```

または、Claude Code のスキルを使用:

```
> /git-worktrees
```

### 3-3. 自律実装の開始

worktree 内で Claude Code を起動し、リリース仕様書に従って実装を進める。

```bash
cd .worktrees/release-my-first-feature
claude
```

Claude Code に以下を指示する:

```
リリース仕様書 .claude/release-specs/my-first-feature.md に従って実装してください。
TDD で進めてください。
```

### 3-4. チェックと PR 作成

```bash
# プロジェクトのチェックコマンドを実行
# 例: npm test, pnpm check, cargo test 等

# PR を作成（統合ブランチ向け）
gh pr create --base develop
```

### 3-5. マージと振り返り

- レビューを通過したら統合ブランチにマージ
- フィードバック会で振り返り
- 必要に応じて本番ブランチに昇格

## Step 4: カスタマイズのヒント

### hook のカスタマイズ

hook スクリプトは `.claude/hooks/` に配置されている。プロジェクトの要件に応じて修正できる。

```bash
# 例: worktree-guard.sh にプロジェクト固有の除外パスを追加
# 例: commit-guard.sh に保護ブランチを追加
```

### スキルの追加

プロジェクト固有のスキルを `.claude/skills/` に追加できる。

```bash
# 例: データベースマイグレーション支援スキル
# 例: デプロイメント手順スキル
```

### エージェントの定義

反復的なタスクにはエージェントを定義する。

```bash
# 例: .claude/agents/code-reviewer.md
# 例: .claude/agents/implementer.md
```

## 次のステップ

初回のリリースサイクルが完了したら、以下を検討する:

1. **採用レベルの引き上げ**: [adoption-levels.md](./adoption-levels.md) を参照し、次のレベルの機能を有効化
2. **VDD アーティファクトの導入**: Vision 正本と意思決定台帳の運用を開始（L4）
3. **クラウド実行の設定**: MacBook に依存しないヘッドレス実行環境の構築（L5）

## トラブルシュート

| 問題 | 対処 |
|------|------|
| hook が動作しない | `.claude/settings.json` の `hooks` セクションを確認。スクリプトに実行権限があるか確認 (`chmod +x`) |
| worktree の作成に失敗 | `.worktrees/` ディレクトリが存在するか確認。既存の worktree と重複していないか確認 |
| Claude Code がルールを無視する | hook の強制レベルを確認。L2（プロンプト内ルール）は技術的強制がないため、L4/L5 への引き上げを検討 |
| サブエージェントがルールに従わない | `subagent-rules/inject.sh` が正しく設定されているか確認 |

## 関連ドキュメント

- [philosophy.md](./philosophy.md) — VDD の哲学
- [adoption-levels.md](./adoption-levels.md) — 段階的採用パス
- [enforcement-levels.md](./enforcement-levels.md) — 強制レベル階層
