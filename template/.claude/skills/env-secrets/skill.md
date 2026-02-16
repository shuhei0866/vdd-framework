---
name: env-secrets
description: 環境変数の参照、.env ファイルの操作、シークレットキーの調査、API キーの確認が必要な時に使用する。安全な取り扱い方法を提供し、漏洩を防止する。
---

# 環境変数・シークレット管理スキル

このスキルはプロジェクトで環境変数やシークレットを安全に扱う方法を提供します。

## 最重要ルール: AI によるシークレット漏洩の防止

### .env ファイルの直接読み取り禁止

**AI（Claude Code）は `.env` / `.env.local` ファイルの内容を絶対に読んではならない。**

- `Read` ツールで `.env.local` を開かない
- `cat`, `head`, `tail` で `.env.local` を表示しない
- `grep` で `.env.local` の内容を出力しない
- `.env.local` の内容がセッションログに記録され、平文シークレットが永続化するため

`settings.local.json` の `permissions.deny` で技術的にブロックされているが、ルールとしても明示する。

### シークレットを含むコマンド出力の禁止

- API キーやシークレットを含む行を出力するコマンドを実行しない
- `git grep` や `grep` の出力にシークレットが含まれる場合、その出力はセッションログに記録される
- `allow` エントリに平文シークレットを含むコマンドを許可しない

## シークレット漏洩調査の安全な方法

シークレットが漏洩していないか調査する際は、**マッチした行の内容を出力しない**ことが絶対条件。

### OK パターン（安全）

```bash
# ファイル名のみ出力（-l）
grep -rl '<secret-prefix>' /path/to/search/

# カウントのみ出力（-c）
grep -rc '<secret-prefix>' /path/to/search/ | grep -v ':0$'

# git 内のファイル名のみ（--name-only）
git log --all -S '<secret-prefix>' --name-only --oneline

# git grep でファイル名のみ
git grep -l '<secret-prefix>' --all
```

### NG パターン（危険）

```bash
# NG: マッチ行が出力され、シークレット全体がセッションログに記録される
grep -r '<secret-prefix>' /path/to/search/
git grep '<secret-prefix>' --all

# NG: .env.local の内容を表示
grep 'SECRET' .env.local
cat .env.local
```

## 使用タイミング

- リモートサービスに接続するとき
- パスワードや API キーを使うコマンドを実行するとき
- 環境変数を読み込んでスクリプトを実行するとき
- **シークレットの漏洩調査を行うとき**
- **`.env` / `.env.local` に関わる操作全般**

## 安全な環境変数の読み込み方法

### パターン1: source で読み込んで使用（推奨）

```bash
# .env.local を読み込んで環境変数として使用
source /path/to/project/.env.local
# 変数を参照して使用
echo "Using $VARIABLE_NAME"
```

**メリット**: コマンド履歴にシークレットが残らない

### パターン2: サブシェルで読み込み

```bash
# 1行で完結させる場合
(source /path/to/project/.env.local && command-using-$VARIABLE)
```

### パターン3: grep + cut で抽出

```bash
# 特定の変数だけ取り出す場合
VARIABLE="$(grep VARIABLE_NAME /path/to/.env.local | cut -d= -f2)"
```

## NG パターン（やってはいけない）

```bash
# NG: シークレットがコマンド履歴に残る
command "actual-secret-value"

# NG: シークレットを直接指定
API_KEY='actual-api-key' command

# NG: .env.local を Read ツールで読む
# Read(.env.local) <- 禁止

# NG: grep で .env.local の内容を表示
grep 'SECRET' .env.local
cat .env.local
```

## 多層防御の構成

シークレット保護は以下の3層で実現する：

1. **permissions.deny（決定論的・最も確実）**: `settings.local.json` で `.env.local` の Read をブロック
2. **スキルのルール（AI の行動指針）**: このスキルで定義された禁止事項・安全パターン
3. **コマンドパターン（運用ルール）**: `source` + 変数参照による間接アクセス

### permissions.deny の設定例

`settings.local.json` に以下を追加する。**Read ツールは絶対パスを受け取るため、`//` プレフィックスの絶対パスパターンが最も確実に動作する。**

```json
{
  "permissions": {
    "deny": [
      "Read(//Users/**/.env.local)",
      "Read(//Users/**/.env)",
      "Read(//Users/**/.env.*)",
      "Bash(cat *.env.local*)",
      "Bash(cat */.env.local*)",
      "Bash(grep *.env.local*)",
      "Bash(grep */.env.local*)",
      "Bash(head *.env.local*)",
      "Bash(tail *.env.local*)",
      "Bash(source *.env.local*)",
      "Bash(source */.env.local*)"
    ]
  }
}
```

### パターン構文の注意点

| 構文 | 意味 | 備考 |
|------|------|------|
| `//path` | ファイルシステムの絶対パス | **Read で最も確実** |
| `~/path` | ホームディレクトリからの相対パス | |
| `./path` | 設定ファイルからの相対パス | |
| `**` | 任意の深さのディレクトリ | |
| `*` | 単一ディレクトリ内のワイルドカード | |

## チェックリスト

環境変数を使うコマンドを実行する前に確認：

- [ ] `.env.local` を Read ツールで直接読もうとしていないか
- [ ] パスワードや API キーを直接コマンドに書いていないか
- [ ] `source` で .env ファイルを読み込んでいるか
- [ ] 変数参照（`$VARIABLE`）を使っているか
- [ ] シークレット調査で `-l`（ファイル名のみ）や `-c`（カウントのみ）を使っているか

シークレット調査時に確認：

- [ ] `git grep -l` または `git grep -c` を使い、出力は値を含まないか
- [ ] サブエージェントに調査させていないか
- [ ] 検索パターンが部分文字列に留まっているか
- [ ] 漏洩が確認されたら、シークレットのローテーション優先で実施しているか
