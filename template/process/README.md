# process/

このディレクトリは、VDD Framework のプロセス仕様の**ツール非依存な正本**を保管する。

## ファイル構成

| ファイル | 説明 |
|---------|------|
| `VDD.md` | Vision-Driven Development の方法論。ビジョン管理、意思決定台帳、運用ループを定義 |
| `RDD.md` | Release-Driven Development の方法論。リリース単位の開発プロセスを定義 |

## 正本とツール実装の関係

```
process/VDD.md  ─── ツール非依存の方法論
process/RDD.md  ─── ツール非依存の方法論
     |
     v
CLAUDE.md       ─── Claude Code で運用するための具体設定
                    （フック、スキル、強制ルール、実装パス）
```

- `process/*.md` は「何をするか」「なぜするか」を記述する
- `CLAUDE.md` は「どうやるか」（ツール固有の手順）を記述する
- プロセスの変更は `process/*.md` を先に更新し、`CLAUDE.md` に反映する
