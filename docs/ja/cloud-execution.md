# ヘッドレス VPS 実行

## 概要

VDD/RDD の Phase 2-3（自律実装 → レビュー → 統合ブランチへのマージ）をローカルマシンに依存せず実行するためのガイド。設計対話（Phase 0-1）は対話的にローカルで行い、実装（Phase 2-3）は VPS に任せてローカルマシンを閉じられるようにする。

## なぜ必要か

ローカルマシン（MacBook 等）のスリープで AI の自律実行が中断される問題を解決する。AI が数時間かけて TDD → レビュー → PR 作成 → マージまでを自律的に行う場合、その間ローカルマシンを起動し続ける必要がない。

## インフラ要件

| 項目 | 推奨 |
|------|------|
| マシンスペック | 4 vCPU / 16GB RAM 以上 |
| OS | Ubuntu 24.04 LTS 等の Linux |
| 主要ツール | Node.js (LTS), パッケージマネージャー, tmux, Claude Code CLI |
| アクセス | SSH（セキュアトンネル推奨） |

### プロバイダの選択

特定のクラウドプロバイダに依存しない。以下のいずれでも運用可能:

- Google Cloud (GCE)
- AWS (EC2)
- DigitalOcean
- Hetzner
- 自宅サーバー

コスト意識: 使わない時間はインスタンスを停止して料金を抑える。

## 基本操作

### tmux セッション管理

tmux を使うことで、SSH 接続が切れても VPS 上のプロセスが動き続ける。

```bash
# 新規セッション作成
tmux new-session -s rdd

# デタッチ: Ctrl+B → D（ローカルマシンを閉じても VPS 上で動き続ける）

# 再接続
tmux attach -t rdd

# セッション一覧
tmux list-sessions

# セッション終了
tmux kill-session -t rdd
```

## RDD ワークフロー（headless 実行）

### 前提

- リリース仕様書が作成・push 済みであること
- VPS のリポジトリが最新であること

### 手順

#### 1. VPS に SSH して tmux セッション作成

```bash
ssh your-vps
tmux new-session -s release-{name}
```

#### 2. Claude Code を headless で起動

```bash
cd ~/your-project
claude -p "
リリース仕様書 .claude/release-specs/{name}.md に従って実装してください。

手順:
1. worktree を作成し release/{name} ブランチで作業
2. TDD で実装（テストファースト厳守）
3. チェックコマンドを通す（型チェック + lint + テスト）
4. 自己評価を実行
5. 独立レビューを実行
6. 指摘があれば修正してコミット
7. PR を作成（統合ブランチ向け）
8. 独立レビュアーの approve を待機
9. approve 確認後、マージ

完了したら結果を報告してください。
" --allowedTools "Bash,Read,Write,Edit,Glob,Grep"
```

#### 3. tmux をデタッチしてローカルマシンを閉じる

```
Ctrl+B → D
```

#### 4. 進捗確認（いつでも、どこからでも）

```bash
ssh your-vps
tmux attach -t release-{name}
```

### 複数リリースの並列実行

リリースツリーで並列可能なリリースは、別々の tmux セッションで同時実行できる。

```bash
tmux new-session -d -s release-a
tmux send-keys -t release-a "cd ~/your-project && claude -p '...' --allowedTools '...'" Enter

tmux new-session -d -s release-b
tmux send-keys -t release-b "cd ~/your-project && claude -p '...' --allowedTools '...'" Enter
```

**注意**: 並列実行時はファイル競合に注意。各リリースが編集するファイルが重複しないことを確認する。

## 日常運用フロー

```
[ローカル] 設計対話 (Phase 0-1)
    │
    ├── リリース仕様書を作成
    ├── git push
    │
    ▼
[VPS] 自律実装 (Phase 2-3)
    │
    ├── headless で Claude Code 起動
    ├── TDD 実装 → レビュー → PR 作成
    ├── 独立レビュアーの approve をポーリング待ち
    ├── approve 確認後、統合ブランチにマージ
    │
    ▼
[ローカル / モバイル] 確認
    │
    ├── PR・プレビュー環境を確認
    ├── フィードバック会で本番昇格判断
    │
    ▼
[どこからでも] 統合 → 本番昇格
```

## 通知システム

VPS 上の Claude Code がセッション中の重要イベントを通知する仕組みを構築することを推奨する。

### 通知チャネルの例

| 方式 | 方向 | 用途 |
|------|------|------|
| Webhook | VPS → チャット | PR 作成、エラー等の通知 |
| Hook (Stop) | VPS → チャット | セッション完了の通知 |
| チャットボット | 双方向 | 独立レビュアーからの指示受信 |

### 実装のヒント

- Discord / Slack の Webhook を使うのが最も手軽
- Stop hook でセッション完了時に自動通知
- CLAUDE.md にルールとして「PR 作成後に通知を送る」と記載

## メンテナンス

### リポジトリ更新

VPS 上のリポジトリは定期的に pull する。

```bash
cd ~/your-project && git pull origin develop
```

### Claude Code の更新

```bash
sudo npm install -g @anthropic-ai/claude-code
```

### 認証の更新

Claude Code の認証トークンが切れた場合:

```bash
claude login
# 表示される URL をブラウザで開いて認証
```

### ディスク容量

worktree が蓄積するとディスクを圧迫する。不要な worktree は削除する。

```bash
git worktree list
git worktree remove <path>
```

## トラブルシュート

| 問題 | 対処 |
|------|------|
| SSH 接続拒否 | インスタンス起動直後は数十秒待つ。セキュアトンネルの設定を確認 |
| Claude Code 認証切れ | `claude login` で再認証 |
| パッケージインストール失敗 | ランタイムバージョンを確認 |
| tmux セッションが消えた | VPS が再起動された可能性。`tmux list-sessions` で確認 |
| ディスク不足 | `df -h /` で確認。不要な worktree を削除 |

## コスト最適化

- **使わないときは停止する**: インスタンス停止中はディスク料金のみ
- **スポットインスタンスの検討**: 中断されても worktree + git で作業は保全される
- **適切なスペック選択**: AI の実行には CPU/RAM が重要。GPU は不要

## 関連ドキュメント

- [RDD.md](./RDD.md) — RDD のフェーズ（Phase 2-3 が VPS 実行の対象）
- [branch-strategy.md](./branch-strategy.md) — ブランチ戦略
- [adoption-levels.md](./adoption-levels.md) — L5: Full Autonomous に該当
