# VDD 運用ディレクトリ

このディレクトリは、VDD（Vision-Driven Development）の**実運用データ**を保管する。
方法論そのものの正本は `process/VDD.md` を参照する。

## ファイル構成

- `VISION.md`: 現在のビジョンの正本
- `DECISIONS.md`: 意思決定の履歴台帳
- `DAILY_SCORE.md`: 日次主観スコアの記録

## 運用ルール

1. 定期的な会議で、AI提案 -> 人間承認（`approve/reject/conditional`）を行う
2. 会議で扱った意思決定を `DECISIONS.md` に追記する（`decision_id` 必須）
3. `conditional` は自由文条件で記述し、条件達成は運用で判断する
4. `conditional` の条件が満たされるまで実装着手不可
5. ステータスは `active` / `dropped` / `superseded` の3つ
6. 日次主観スコアを `DAILY_SCORE.md` に記録する
7. 方向性が変わったら `VISION.md` を更新する（毎日更新は必須ではない）
8. 新しいリリースを起こすときは `release-spec` で両方を参照する

## 参照

- 共通仕様: `process/VDD.md`
- 実装レイヤー: `CLAUDE.md`
