# DTD クイックスタート — 30秒で Hello

最小の end-to-end ウォークスルー。ワーカー1人、タスク1つ、ファイル1つ。

言語選択: [English](quickstart.md) · [한국어](quickstart.ko.md)

---

## 前提

- agentic LLM (filesystem read/write **+** shell-exec または web-fetch)。
  Claude Code、Codex CLI、Cursor、OpenCode、Aider などすべて動きます。
- ワーカー LLM エンドポイント1つ。最も簡単なのはローカル
  [Ollama](https://ollama.com) — `deepseek-coder:6.7b` などのモデル。
  無料、キー不要、ネットワーク不要。

---

## 1. インストール (1行)

プロジェクトディレクトリで、エージェントに一言:

```text
github の daystar7777/dtd から prompt.md を取得してこのプロジェクトにインストールして
```

エージェントがブートストラップを取得し、ホストの能力を検出して `.dtd/`
ツリーを作成し、`dtd.md` を配置し、`CLAUDE.md` / `.cursorrules` /
`AGENTS.md` に1行のポインタを追加します。約30秒。

このように表示されます:

```
✓ DTD installed.

  host_mode:      full
  DTD mode:       off (toggle on via /dtd mode on)
  Files written:  15 templates + dtd.md
  Host pointer:   appended to CLAUDE.md
  AIMemory:       absent (optional, see recommendation)
```

---

## 2. 最初のワーカーを登録

```text
/dtd workers add
```

対話形式のプロンプト。ローカル Ollama の場合:

```text
worker_id (kebab-case):     deepseek-local
endpoint:                    http://localhost:11434/v1/chat/completions
model:                       deepseek-coder:6.7b
api_key_env:                 OLLAMA_API_KEY
max_context (tokens):        32000
capabilities (csv):          code-write, code-refactor
aliases (csv, optional):     ディープシーク
tier (1-3):                  1
permission_profile:          code-write
escalate_to (worker | user): user

✓ Added worker 'deepseek-local' (aliases: ディープシーク). Registry now has 1 worker.
```

または自然言語で:

```text
「ディープシークのワーカー追加して。localhost:11434、code-write で。」
```

環境変数を設定:

```bash
export OLLAMA_API_KEY=ollama   # Ollama は実際のキー不要
```

---

## 3. DTD モードを ON

```text
/dtd mode on
```

ホスト LLM (「コントローラー」) が毎ターン `.dtd/instructions.md` を
ロードし始めます。自然言語コマンドがルーティングされます。

---

## 4. Plan → approve → run

```text
/dtd plan "src/hello.js に hello-world エンドポイントを追加"
```

コントローラーが DRAFT プランを作成し、ワーカー割当てを表示します:

```
+ plan-001 [DRAFT]
| goal: src/hello.js に hello-world エンドポイントを追加
+ tasks
| Task | Goal                       | Worker      | Work paths | Output paths   | Assigned via
| 1.1  | hello-world エンドポイント実装 | ディープシーク | src/       | src/hello.js   | capability:code-write
+ phases
| phase 1: implement  workers: ディープシーク  touches: src/

— Approve as-is:  /dtd approve
— Swap worker:    /dtd plan worker <task_id|phase:N|all> <worker>
— Re-plan:        /dtd plan <new goal>
```

プラン OK?

```text
/dtd approve
/dtd run
```

ダッシュボード:

```
+ DTD plan-001 [RUNNING] phase 1/1 implement | iter 1/2 | NORMAL < GOOD | ctx 4% | total 5s
| current   1.1 hello-world エンドポイント実装
| worker    deepseek-local (tier 1) profile=code-write
| work      src/
| writing   src/hello.js (live)
| locks     write files:project:src/hello.js
| elapsed   total 5s | phase 5s | task 5s
+ pause: /dtd pause  or  "ちょっと止めて"
```

数秒後:

```
+ DTD plan-001 [COMPLETED] grade=GOOD | total 12s
| 1.1 hello-world エンドポイント実装  [ディープシーク]  src/hello.js  GOOD  12s

✓ run-001 done. Summary: .dtd/log/run-001-summary.md
✓ Notepad archived: .dtd/runs/run-001-notepad.md
```

---

## 5. 完了

`src/hello.js` ファイルが作成されました。開いてみるとワーカーの出力です。

これで:

- `/dtd plan "<次の目標>"` — 次の作業
- `/dtd workers add` — ワーカーをさらに登録
- `/dtd status` — いつでも現在の状態を確認
- `/dtd doctor` — ヘルスチェック
- `/dtd uninstall --soft` — クリーンに OFF (`.dtd/` 保持)

---

## 今、何が起きたか

1. **コントローラー** (ホスト LLM) が phase 別のプランを作成し、ユーザー承認を要求。
2. approve 後、コントローラーが task 1.1 を **ワーカー** (`deepseek-local`) に HTTP ディスパッチ → レスポンス待機。
3. コントローラーがワーカー出力パスを permission/lock ポリシーで検証 → 通過 → ファイル適用。
4. COMPLETED 時に `finalize_run` が notepad アーカイブ、summary 作成、lease 解放、state 更新。
5. AIMemory がある場合は `WORK_START` + `WORK_END` の2イベントだけ。終わり。

オーケストレーションサーバーなし。SDK なし。SaaS なし。`.dtd/` 内の
マークダウン + task ごとに HTTP 1回。

---

## 次のステップ

- **レビュアーワーカー追加** — クロス LLM パイプライン (作者 → レビュアー → 修正者):
  `/dtd workers add` で `capabilities: review` + 別のモデル。
- **実行中の方向転換**: 「今回は安定性優先で」→ patch が作成され、ユーザー確認。
- **マルチ phase プラン**: [plan-001.md 例](plan-001.md) に 5-phase + parallel-group + cross-vendor パイプラインのデモ。
- **フル仕様**: [dtd.md](../dtd.md) (~22 KB、すべての canonical action)。
- **コントローラー行動ルール**: [.dtd/instructions.md](../.dtd/instructions.md)。

[メイン README に戻る](../README.ja.md)。
