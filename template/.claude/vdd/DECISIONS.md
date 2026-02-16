# DECISIONS

会議での意思決定を履歴として残す。自然言語でよい。

## 記録ルール

- 1 行 = 1 意思決定
- `decision_id` を必ず付与する（例: `D-20260207-01`、日次リセット）
- `decision` は「何を決めたか」を短く書く
- `context` は「なぜそう判断したか」を書く（必須）
- `approval` は `approve / reject / conditional`
- `conditional` は条件が満たされるまで実装着手不可
- 過去決定を置換する場合は `supersedes` の decision_id を `status` 備考に書く

## ステータス

- `active`: 有効な決定
- `dropped`: 撤回された決定
- `superseded`: 新しい決定で置き換えられた決定

## Decision Ledger

| decision_id | date | decision | context | approval | status |
|---|---|---|---|---|---|
| D-YYYYMMDD-01 | YYYY-MM-DD | （ここに決定内容を記入） | （ここに判断理由を記入） | approve | active |
