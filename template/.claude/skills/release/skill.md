---
name: release
description: release/* ブランチのマージ後にバージョンタグが必要な時、GitHub Release を作成する時、または /release と呼ばれた時に使用する。コミット履歴からリリースノートを自動生成する。
context: fork
agent: release-manager
---

# リリース作成スキル

このスキルは GitHub リリースを作成します。

## 使用タイミング

- `release/*` ブランチのマージ後、リリース仕様書（`.claude/release-specs/{release-name}.md`）の分類が **バージョンタグ対象** の場合
- `/release` コマンドが呼ばれたとき
- developer-only のリリースでは実行不要

## VDD リリース分類の確認

リリース作成前に、マージされたリリース仕様書（`.claude/release-specs/{release-name}.md`）の「リリース分類」セクションを確認する：

- **developer-only** → このスキルの実行は不要。終了
- **user-facing** → 以下のリリース手順に進む

## リリース手順

### 1. 現在の状態を確認

```bash
# 最新のタグを確認
git tag --list --sort=-v:refname | head -5

# 前回リリースからの変更を確認
git log $(git describe --tags --abbrev=0 2>/dev/null || echo "")..HEAD --oneline
```

### 2. バージョン番号の決定

セマンティックバージョニング（major.minor.patch）に従う：

- **patch** (0.1.0 → 0.1.1): バグ修正のみ
- **minor** (0.1.0 → 0.2.0): 新機能追加（後方互換性あり）
- **major** (0.1.0 → 1.0.0): 破壊的変更

ユーザーに確認：「次のバージョンは何にしますか？」
- 選択肢: patch / minor / major / 指定のバージョン

### 3. リリースノートの構成

コミット履歴から以下のカテゴリに分類：

```markdown
## 新機能 (Features)
- feat: で始まるコミット

## バグ修正 (Bug Fixes)
- fix: で始まるコミット

## パフォーマンス改善 (Performance)
- perf: で始まるコミット

## ドキュメント (Documentation)
- docs: で始まるコミット

## その他 (Others)
- chore:, refactor:, style:, test: などのコミット
```

### 4. リリース作成コマンド

```bash
# GitHubリリースを作成（タグも自動作成される）
gh release create v<VERSION> --title "v<VERSION>" --notes "$(cat <<'EOF'
## 変更内容

### 新機能
- 機能1
- 機能2

### バグ修正
- 修正1
EOF
)"
```

### 5. 確認

```bash
# リリースが作成されたか確認
gh release list --limit 5
```

## リリース前チェックリスト

リリース作成前に確認：

- [ ] `{{CHECK_COMMAND}}` が通るか
- [ ] main ブランチにマージ済みか
- [ ] 未コミットの変更がないか

```bash
# チェック実行
{{CHECK_COMMAND}}

# ブランチ確認
git branch --show-current

# 未コミット確認
git status
```

## コミットメッセージのプレフィックス

| プレフィックス | カテゴリ | 例 |
|--------------|--------|-----|
| `feat:` | 新機能 | feat: add user profile page |
| `fix:` | バグ修正 | fix: correct login redirect |
| `perf:` | パフォーマンス | perf: optimize image loading |
| `docs:` | ドキュメント | docs: update README |
| `chore:` | 雑務 | chore: update dependencies |
| `refactor:` | リファクタリング | refactor: extract helper |
| `style:` | スタイル | style: format code |
| `test:` | テスト | test: add unit tests |

## トラブルシューティング

### タグが既に存在する場合

```bash
# タグを削除してやり直す（ローカル）
git tag -d v<VERSION>

# リモートのタグを削除
git push origin :refs/tags/v<VERSION>
```

### リリースを削除する場合

```bash
gh release delete v<VERSION> --yes
```
