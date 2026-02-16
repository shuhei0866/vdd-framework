# 強制レベル階層

## 概要

VDD Framework では、ルールの重要度に応じて4段階の強制レベルを定義している。最も重要なルールは技術的に回避不可能にし、ガイドライン的なルールはプロンプト内に記載するのみとする。この階層設計により、「絶対に守るべきこと」と「判断に委ねること」を明確に区別する。

## 強制レベル一覧

| レベル | ラベル | 技術的手段 | 意味 |
|--------|--------|-----------|------|
| **L5** | フック強制 (deny) | Claude Code hook (`deny`) | 技術的にブロック。回避不可 |
| **L4** | フック警告 (ask/block) | Claude Code hook (`ask`/`block`) | ユーザー確認を要求。意図的な上書きは可能 |
| **L3** | コンテキスト注入 | SubagentStart hook | サブエージェント起動時にルールを自動注入 |
| **L2** | プロンプト内ルール | CLAUDE.md 記載 | ドキュメントに記載のみ。技術的強制なし |

## 各レベルの詳細

### L5: フック強制（deny）

**最高レベルの強制。AI が物理的にルールを破れない。**

hook が `deny` を返すと、Claude Code はそのツール呼び出しを実行せずに中断する。AI はこのブロックを回避する手段を持たない。

#### 設計意図

- 不可逆で重大な被害をもたらすルール違反を防止する
- 人間の承認でも上書きできない「絶対防壁」
- 最も重要なルールのみに適用する（乱用すると AI の自律性を過度に制限する）

#### 適用例

| hook | 防止する操作 |
|------|-------------|
| `worktree-guard.sh` | メインワークツリーでのファイル編集 |
| `commit-guard.sh` | 保護ブランチへの直接コミット、`--no-verify`、force push |
| `commit-guard.sh` | メインワークツリーでの `git checkout`/`switch`/`stash pop` |

#### 実装パターン

```bash
#!/bin/bash
# PreToolUse hook (Write/Edit)
# deny を返すとツール呼び出しがブロックされる

WORKTREE_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
MAIN_REPO_ROOT="/path/to/main/repo"

if [ "$WORKTREE_ROOT" = "$MAIN_REPO_ROOT" ]; then
  echo '{"decision": "deny", "reason": "メインワークツリーでのファイル編集は禁止されています。worktree を作成してください。"}'
  exit 0
fi

echo '{"decision": "allow"}'
```

---

### L4: フック警告（ask/block）

**重要だが、人間の判断で上書きできるレベル。**

hook が `ask` を返すと、Claude Code はユーザーに確認を求める。ユーザーが承認すれば操作は実行される。`block` は Stop フック用で、AI の停止を試みる。

#### 設計意図

- 重要だが例外が存在するルールに適用する
- 人間が状況を判断して上書きできる余地を残す
- 「うっかり」は防止しつつ、意図的な操作は許可する

#### 適用例

| hook | 検出する操作 |
|------|-------------|
| `migration-guard.sh` | マイグレーション番号の重複 |
| `review-enforcement/check.sh` | リリースブランチでのレビュー未実行 |

#### 実装パターン

```bash
#!/bin/bash
# PreToolUse hook (Write/Edit)
# ask を返すとユーザーに確認を求める

EXISTING_NUMBERS=$(ls migrations/ | grep -oP '^\d+' | sort -u)
NEW_NUMBER=$(echo "$FILE_PATH" | grep -oP '^\d+')

if echo "$EXISTING_NUMBERS" | grep -q "^${NEW_NUMBER}$"; then
  echo '{"decision": "ask", "reason": "マイグレーション番号 '"$NEW_NUMBER"' は既に存在します。重複していませんか？"}'
  exit 0
fi

echo '{"decision": "allow"}'
```

---

### L3: コンテキスト注入

**サブエージェントへの自動ルール伝達。**

SubagentStart hook で、サブエージェントの起動時にルールを `additionalContext` として注入する。サブエージェントはこのコンテキストを受け取り、ルールに従って動作する。

#### 設計意図

- メインエージェントのルールをサブエージェントに自動伝達する
- プロンプトに明示しなくても、重要なルールが確実に伝わる
- エージェントの種類（implementer, reviewer 等）に応じて注入内容を変える

#### 適用例

| 注入内容 | 対象エージェント |
|---------|----------------|
| TDD 必須ルール | implementer, general-purpose |
| worktree 使用義務 | 全エージェント |
| レビュー組み込みルール | release/* で作業するエージェント |

#### 実装パターン

```bash
#!/bin/bash
# SubagentStart hook
# additionalContext でルールを注入

AGENT_TYPE="$1"  # implementer, reviewer, etc.

RULES="[必須ルール]
- メインワークツリーでのファイル編集は禁止。worktree 内で作業すること
- git push は禁止。コミットまでは可能"

if [ "$AGENT_TYPE" = "implementer" ]; then
  RULES="$RULES
- TDD（テスト駆動開発）必須。テストファーストで実装すること"
fi

echo "$RULES"
```

---

### L2: プロンプト内ルール

**最低限の強制。CLAUDE.md への記載のみ。**

技術的な強制手段を持たない。AI がドキュメントを読み、自発的にルールに従うことを期待する。

#### 設計意図

- ガイドラインや推奨事項に適用する
- 技術的強制のコストが見合わないルールに使用する
- AI の判断力に委ねられる程度のルール

#### 適用例

- コーディングスタイルのガイドライン
- コミットメッセージのフォーマット
- ドキュメントの書き方
- アーキテクチャの推奨パターン

#### 注意点

L2 のルールは AI が無視する可能性がある。重要なルールは L3 以上に引き上げることを検討する。

---

## レベル選択の判断基準

```
このルールが破られたら、取り返しのつかない被害が生じるか？
├── Yes → L5: deny
└── No
    ├── 破られたら問題だが、人間が判断すれば例外を認められるか？
    │   ├── Yes → L4: ask/block
    │   └── No → L5: deny
    └── サブエージェントにも確実に伝える必要があるか？
        ├── Yes → L3: コンテキスト注入
        └── No → L2: プロンプト内ルール
```

## レベル間の関係

高いレベルは低いレベルを包含しない。それぞれ独立した強制手段である。

- L5 の hook と L2 の CLAUDE.md 記載を併用することが一般的
- 例: worktree-guard は L5 (deny) で技術的にブロックし、CLAUDE.md (L2) にも「なぜ worktree を使うか」の理由を記載する
- L3 の注入内容には L2 のルールの要約を含めることが多い（二重安全）

## アンチパターン

| アンチパターン | 問題 | 対処 |
|--------------|------|------|
| 全てのルールを L5 にする | AI の自律性が過度に制限される | 本当に不可逆な操作のみ L5 に |
| 重要なルールを L2 のみにする | AI が無視するリスクがある | L3 以上への引き上げを検討 |
| L3 注入を過剰に行う | サブエージェントのコンテキストが肥大化 | 必須ルールのみ注入 |
| L4 の確認が頻発する | ユーザーが「承認疲れ」で盲目的に承認 | 頻発するものは L5 (deny) か L2 に移動 |

## 関連ドキュメント

- [philosophy.md](./philosophy.md) — 「ルールを技術的に強制する」思想の背景
- [adoption-levels.md](./adoption-levels.md) — 採用レベルと含まれる hook の対応
