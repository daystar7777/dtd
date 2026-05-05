# DTD (Do Till Done)

> 安い LLM が実作業をする。高い LLM はただ指揮するだけ。
> マークダウンだけで作るマルチ LLM 実行モード — どのエージェントでも動きます。

[English README](README.md) · [한국어 README](README.ko.md)

---

## なぜ必要?

優れたエージェントは沢山あります — Claude Code、Codex、Cursor、Antigravity、Aider。
でも一度に1つしか使えません。トークンはすぐ尽きるし、タスクごとに得意なモデルが違います。

DTD はホスト LLM を **コントローラー** に変えます。
プランを立て、ユーザー承認を求め、各タスクを **ワーカー LLM** にディスパッチします。

Codex で設計、DeepSeek で実装、GPT-Codex でレビュー、再び DeepSeek で修正 —
1つのプラン、1つのコマンド。

サーバー不要。SDK 不要。クラウド不要。`.dtd/` フォルダ1つで完結。

---

## インストール

プロジェクトのエージェントに — どのエージェントでも — 一言:

```text
github の daystar7777/dtd から prompt.md を取得してこのプロジェクトにインストールして
```

エージェントがホストの能力を検出し、`.dtd/` ツリーを構築し、
スラッシュコマンドをホスト固有のパスに配置し、`CLAUDE.md` /
`.cursorrules` / `AGENTS.md` に1行のポインタを追加します。

→ **とりあえず試してみたい?** [30秒クイックスタート](examples/quickstart.ja.md) でインストール → 最初のプラン → 最初の実行までローカルワーカー1人で歩めます。

---

## どう使う?

スラッシュ — 3 つのグループ: **開始 / 観察 / 復旧**.

開始 (Start):

```text
/dtd workers add                 最初のワーカー LLM を登録
/dtd workers test <id>           基本接続チェック (env / endpoint / auth)
/dtd mode on                     DTD モードを ON
/dtd plan "API追加"               phase 別プラン作成 (DRAFT)
/dtd approve                     プラン確定
/dtd run                         実行
/dtd run --silent=4h             静かに進行; ブロッカーは保留して安全な task を続行 (v0.2.0f)
```

実行モード (Run styles, v0.2.0f):

```text
/dtd run --decision permission   既定: 権限/重要な選択を確認
/dtd run --decision auto         安全な前進を最大化 (destructive / 有料 / 外部パスは引き続き confirm)
/dtd interactive                 決定が必要な時に即座に確認
/dtd silent on --for 4h          interrupt しない; 保留されたブロッカーは後で表示
```

観察 (Observe):

```text
/dtd status                      ダッシュボード
/dtd plan show                   現在のプラン詳細
/dtd doctor                      ヘルスチェック
/dtd workers list                登録済みワーカー一覧
/dtd help [topic]                階層型ヘルプ (≤25行概要、≤50行トピック)
/dtd update check                最新 DTD バージョン確認 (v0.2.0d)
/dtd r2 readiness                v0.3 ライブテスト入口ゲート; ワーカー呼び出しなし
```

復旧 (Recover, v0.2.0a Incident Tracking):

```text
/dtd pause                       次のタスク境界で停止
/dtd incident list               ブロック中の事象一覧
/dtd incident show <id>          詳細な失敗理由 + 復旧オプション
/dtd incident resolve <id> retry 復旧オプションを選ぶ
/dtd stop                        強制終了 (destructive)
```

> ワーカーヘルスチェックの詳細診断 (`--all`, `--full`, `--connectivity`,
> ステージログ, 失敗分類) は v0.2.1+ Runtime Resilience で利用可能。

または自然言語で:

```text
「ディープシークのワーカー追加して」
「この目標でプラン作って」
「OK 進めて」
「ちょっと止めて」
「task 3 はクエンに変えて」
「今どこまで進んだ?」
```

同じ動作、別のインターフェース。

---

## どう見える?

### インストール確認画面

```
DTD install plan:
  host_mode:   full     (検出: shell-exec + filesystem rw)
  DTD mode:    off      (後で /dtd mode on で起動)
  AIMemory:    not detected — 推奨
  Files to fetch:
    - dtd.md (スラッシュコマンド)
    - .dtd/ × 15 templates
    - host pointer block → CLAUDE.md
Proceed? (y/n)
```

ブートストラップがホストの能力を最初に検出してから、ユーザー confirm を求めます。
`host_mode` はホスト能力で固定 (plan-only / assisted / full)、`DTD mode` は
ユーザーが後で切り替える ON/OFF トグル。AIMemory はオプション — 無くても DTD は動きます。

### ワーカー割当てが見えるプラン

`/dtd plan "user CRUD endpoints を追加"` の後:

```
+ plan-001 [DRAFT]
| goal: user CRUD endpoints を追加 (POST/GET/PATCH/DELETE /users)
+ tasks
| Task | Goal                          | Worker     | Work paths       | Output paths           | Assigned via
| 1.1  | schema + validation           | qwen       | docs/, src/types | docs/users-schema.md   | role:planner
| 2.1  | POST /users + GET /users/:id  | deepseek   | src/api/users    | src/api/users.ts       | capability:code-write
| 2.2  | PATCH /users/:id + DELETE     | deepseek   | src/api/users    | src/api/users.ts       | capability:code-write
| 3.1  | code review                   | codex      | src/api/users    | docs/review-001.md     | role:reviewer
| 3.2  | apply review fixes            | deepseek   | src/api/users    | src/api/users.ts       | capability:code-write
+ phases
| phase 1: planning  workers: qwen      touches: docs/, src/types/
| phase 2: backend   workers: deepseek  touches: src/api/users/
| phase 3: review    workers: codex+deepseek

— Approve as-is:  /dtd approve
— Swap worker:    /dtd plan worker <task_id|phase:N|all> <worker>
```

各タスクがどのワーカーに渡されるか **そしてなぜか** (`Assigned via` 列) 一目で分かります。
プランは DRAFT — `/dtd approve` 前は何も実行されません。承認前にワーカー
を自由にスワップ可能 (`/dtd plan worker 3.1 deepseek` または NL: 「レビューはクエンで」)。

### Run ダッシュボード (リアルタイム)

`/dtd run` の後:

```
+ DTD plan-001 [RUNNING] phase 2/3 backend | iter 1/3 | NORMAL < GOOD | gate pending | ctx 42% | total 8m
| goal      user CRUD endpoints を追加
| current   2.2 PATCH + DELETE
| worker    deepseek-local (tier 1) profile=code-write
| work      src/api/users
| writing   src/api/users.ts (live)
| locks     write files:project:src/api/users.ts
| elapsed   total 8m | phase 4m | task 3m12s
+ recent
| * 1.1 schema + validation        [qwen]      docs/users-schema.md  GREAT  30s
| * 2.1 POST + GET endpoints       [deepseek]  src/api/users.ts      GOOD   4m
+ queue
| -> 3.1 code review               [codex]
| -> 3.2 apply review fixes        [deepseek]
+ pause: /dtd pause  or  「ちょっと止めて」
```

進行に合わせてダッシュボード更新。grade、gate、コンテキスト使用量、保持中の lock、
elapsed time、完了したもの、キュー。いつでも pause — in-flight タスクをきれいに
完走させてから停止。

### Doctor (ヘルスチェック)

```
$ /dtd doctor

[Install integrity]            ✓ 15/15 templates + dtd.md
[Mode consistency]             ✓ state.md mode=dtd host_mode=full | config.md aligned
[Worker registry]              ✓ 3 active workers (deepseek-local, qwen-remote, gpt-codex)
[agent-work-mem]               ℹ integrated
[Project context]              ✓ PROJECT.md filled
[Resource state]               ✓ 0 active leases
[Plan state]                   ✓ plan-001 RUNNING, size 7.8 KB (≤ 12 preferred)
[Path policy]                  ✓ no violations
[.gitignore]                   ✓ all required entries

verdict: 0 ERROR / 0 WARN / 1 INFO
```

`/dtd doctor` は「今、全部 OK?」のコマンド。ワーカーレジストリの問題、stale lease、
シークレット漏洩、欠落テンプレート、mode 不一致を検出。自動修正はしません — 何が
問題で、どう対処すべきかを教えてくれます。

---

## 何が違う?

**マルチ LLM ルーティング**。ワーカーごとに capability / cost / tier を記述すると
タスクが自動分配。クロス vendor パイプラインが1つのプランに収まります。

**Tier escalation**。ワーカー A が3回失敗すると自動で B へ → レビュアー追加 →
コントローラー直接 → ユーザーに問い合わせ。閾値はワーカーごとに個別設定。
同じ blocker 2回は hash で検知して次のステップへ加速。

**ステートマシン + 承認ゲート**。プランは常に DRAFT で開始。ユーザーが approve するまで
RUNNING になりません。実行中の方向転換 (steering) は patch になり、medium/high
インパクトなら再 confirm が必要。

**Pause / Resume / Stop**。RUNNING 中に停止可能、in-flight タスクはきれいに完走。
次のセッションで再開可能。作業フォルダ / 結果フォルダが plan / status / history に
一貫して表示。

**トークン節約**。ワーカー出力は log ファイルへ、チャットには1行ステータスのみ。
完了タスクは1行圧縮。プロバイダー prompt cache フレンドリーな整列。
ステータス出力ダイエット。

**セキュリティ first-class**。API キーは `.env` のみ、どこにも echo しない。
`doctor` が正規表現で leak 検出。

**モード正直**。3-mode:

- `plan-only` — filesystem のみ、ワーカー呼び出しはユーザー手動 paste
- `assisted` — shell または web-fetch で自動ディスパッチ、必要なら per-call confirm
- `full` — 自律ディスパッチ、破壊的アクションのみ confirm

`/dtd doctor` が現在のホスト capability + mode を報告。

---

## どこで動く?

ホスト結合ゼロ。エージェントが filesystem read/write を持っていれば DTD インストール可。
shell-exec または web-fetch も追加であればワーカー自動ディスパッチまで。

サポート済みパターン: Claude Code、ChatGPT Codex CLI、OpenCode、Cursor、Antigravity、
Aider、Cline、Continue、Windsurf、gemini-cli、その他の agentic harness。

ワーカーエンドポイント: OpenAI 互換ならどれでも — ローカル (Ollama、vLLM、LM Studio、
llama.cpp)、リモート (OpenAI、OpenRouter、DeepSeek API、Hugging Face Inference、
Anthropic-compat shim)。

オプション: [agent-work-mem](https://github.com/daystar7777/agent-work-mem)
— マルチセッション作業履歴。DTD が自動検出して最小限に使用 (run ごとに1ペア + 5例外)。

---

## 何が作られる?

```
プロジェクトルート/
├── コード/
├── CLAUDE.md (またはホスト相当)        ← DTD ポインタ1行追加
├── dtd.md                              ← スラッシュコマンドソース
└── .dtd/
    ├── instructions.md                 ← コントローラー行動仕様
    ├── config.md                       ← グローバル設定
    ├── workers.example.md              ← スキーマ + endpoint 例 (commit 対象)
    ├── workers.md                      ← 実際のレジストリ (gitignored、ローカル専用)
                                           install 時 workers.example.md のコピーとして生成
    ├── worker-system.md                ← ワーカー出力 discipline
    ├── resources.md                    ← active lock/lease
    ├── state.md                        ← ランタイム状態
    ├── steering.md                     ← ユーザー指示履歴
    ├── phase-history.md                ← phase ログ
    ├── PROJECT.md                      ← プロジェクトコンテキスト capsule
    ├── notepad.md                      ← run ごとの wisdom (ワーカーへ handoff)
    ├── plan-NNN.md                     ← /dtd plan 時に生成
    ├── log/                            ← ワーカー呼び出し raw ログ
    ├── attempts/                       ← immutable attempt timeline
    ├── runs/                           ← archived run notepads
    ├── eval/                           ← phase eval (retry 時)
    └── skills/{code-write,review,planning}.md
```

---

## こんな人に良い

- コントローラー (Claude/Codex) でプラン、ローカルワーカー (DeepSeek/Qwen) で実装したい人
- 異なる vendor の LLM でパイプラインを作りたい (作者 ≠ レビュアー ≠ 修正者)
- 数日かかるマルチ phase 作業 — セッションをまたいで pause/resume が必要
- AI 変更を audit log で残したいチーム
- エージェント間でコンテキストをコピペするのに疲れた人
- **既に phase で進行中のプロジェクトに DTD 採用** — install 後 done マークだけで DTD が残りの作業から引き継ぎ。3 パターンを [dtd.md §Adopting DTD](dtd.md#adopting-dtd-on-existing-in-progress-work) に記載。

---

## v0.1 に *無い* もの

- DTD インスタンス間の分散 lock 保証 (global path は best-effort)
- streaming worker response
- Anthropic Messages / Gemini API 直接アダプター (OpenAI 互換 shim 推奨)
- `.dtd/runs/` archive 検索
- `/dtd runs prune` cleanup コマンド

v0.2 / v0.1.1 のロードマップに含まれます。

## v0.2 ライン — 運用強化 + ライフサイクル

仕様完成; ユーザーのタグ承認待ち。incident tracking、permission
ledger、snapshot/revert、runtime resilience (worker health-check +
session resume + loop guard)、notepad v2 + reasoning-utility 後処理、
autonomy & attention モード、locale パック、マイグレーション付き
self-update、モジュール化された spec 抽出が含まれます。

## v0.3 ライン — マルチ-LLM 高度実行

R0 (設計) + R1 (ランタイム) で仕様完成; Codex 最終 GO + タグ待ち。
5 sub-release:

- **v0.3.0a Cross-run loop guard** — 安定シグネチャ ledger が
  within-run guard が見逃す長期失敗パターンを検出します。
- **v0.3.0b トークンレート対応スケジューリング** — TZ 対応 quota
  ウィンドウ + 4 ベンダーの provider-header パース + パーミッション
  ゲートで保護された paid fallback。
- **v0.3.0c マルチワーカー合意ディスパッチ** — `consensus="N"`
  plan 属性、4 つの選択戦略 (`first_passing`、`quality_rubric`、
  `reviewer_consensus`、`vote_unanimous`)、並列 staged outputs、
  group lock、late-result-never-apply 不変条件。
- **v0.3.0d マシン間セッション同期** — ラップトップ/デスクトップ
  間のワーカーセッション affinity (mandatorily 暗号化 payload、
  AES-256-GCM + HKDF-SHA256)、3 バックエンド (filesystem /
  git_branch / none)、SESSION_CONFLICT capsule。
- **v0.3.0e 時間制限パーミッション** — `for 1h` / `until eod` /
  `for run` 自然言語 duration 構文、TZ 対応 named-local スコープ、
  finalize_run auto-prune。

---

## 一行で

> コントローラーが計画を立て、ワーカーが実行し、ユーザーが操縦する。
> **Do till done. 終わるまでやる。**
