# minimal --- VDD Framework 最小構成 (Level 1: Safe Development)

## 概要

VDD Framework の最小構成（Level 1: Safe Development）の例です。ワークツリーによるコード隔離と基本的なコミット衛生ルールのみを含みます。

## VDD レベル

**Level 1: Safe Development** --- AI がメインワークツリーを壊さないための最低限のガードレール。

## 含まれるもの

| ファイル | 説明 |
|---------|------|
| `CLAUDE.md` | ワークツリー必須ルールと hooks テーブル |
| `settings.json` | worktree-guard + commit-guard の2つの hook 設定 |
| `hooks/guardrails/worktree-guard.sh` | メインWTでのファイル編集をブロック [L5] |
| `hooks/guardrails/commit-guard.sh` | 危険な git 操作をブロック [L5] |

## 含まれないもの

- サブエージェントルール注入（Level 2+）
- レビュー強制（Level 3+）
- TDD 必須ルール（Level 3+）
- リリース仕様書テンプレート（Level 4+）
- VDD ファイル（VISION, DECISIONS, DAILY_SCORE）（Level 4+）
- クラウド実行環境設定（Level 5）
- 外部ツール連携（Discord, Codex CLI 等）（Level 5）

## ファイル構成

```
minimal/
├── CLAUDE.md
├── settings.json
└── hooks/
    └── guardrails/
        ├── worktree-guard.sh
        └── commit-guard.sh
```

## セットアップ方法

1. これらのファイルをプロジェクトの `.claude/` ディレクトリにコピーします:

```bash
# プロジェクトルートで実行
mkdir -p .claude/hooks/guardrails
cp examples/minimal/settings.json .claude/settings.json
cp examples/minimal/hooks/guardrails/*.sh .claude/hooks/guardrails/
cp examples/minimal/CLAUDE.md CLAUDE.md
```

2. `.worktrees/` を `.gitignore` に追加します:

```bash
echo '.worktrees/' >> .gitignore
```

3. CLAUDE.md の「プロジェクト概要」セクションをプロジェクトに合わせて編集します。

## 提供される保護

### worktree-guard.sh

- メインワークツリーでのファイル編集（Write/Edit）を deny でブロック
- `.claude/` と `CLAUDE.md` への書き込みは例外的に許可
- ワークツリー内（`.worktrees/` 配下）での作業は許可

### commit-guard.sh

- メインワークツリーの保護ブランチ（main/develop）への直接コミットをブロック
- `--no-verify` によるフックスキップを禁止
- main/master への force push を禁止
- メインワークツリーでの `git checkout`/`git switch` をブロック
- `release/*` から main への直接マージをブロック
- develop ブランチの削除をブロック
- メインワークツリーでの `git stash pop/apply` をブロック

## Level 2 へのアップグレード

Level 2 (Guided Development) にアップグレードするには:

1. **サブエージェントルール注入を追加**:
   - `hooks/subagent-rules/inject.sh` を作成
   - `settings.json` に SubagentStart hook を追加

2. **マイグレーションガードを追加**（DB を使用する場合）:
   - `hooks/guardrails/migration-guard.sh` を作成
   - `settings.json` の Write|Edit matcher に追加

3. **CLAUDE.md にプロジェクト固有のルールを追記**:
   - テスト実行コマンド
   - ビルドコマンド
   - アーキテクチャの概要

VDD Framework のテンプレート（`template/`）を参照して、段階的に機能を追加してください。
