# DTD Locale Pack: ja (Japanese)

> Optional pack. Loaded by controller AFTER `.dtd/instructions.md`
> when `config.md locale.enabled: true` AND `state.md locale_active: ja`.
>
> v0.2.0e R0: minimal Japanese seed pack. R1+ will expand with full
> NL routing additions matching the Korean pack's coverage.

## Pack metadata

- locale: ja
- name: Japanese
- version: v0.2.0e (seed)
- merge_policy: pack_wins_on_conflict
- size_budget_kb: 8

## Slash aliases

```
/ディーティーディー <args>     full katakana alias
```

Routing: detect prefix → strip → normalize to canonical `/dtd` → feed
remainder through Intent Gate. Audit entries always record
`/dtd <action>`, never the Japanese spelling.

## NL routing additions (seed — to be expanded in R1)

| Japanese phrase pattern | Canonical | Required state |
|---|---|---|
| "計画を立てて", "プランを作って" | `plan <inferred goal>` | any (DRAFT overwrite confirms) |
| "OK 進めて", "承認" | `approve` | DRAFT only |
| "実行して", "走らせて", "開始" | `run` | APPROVED or PAUSED |
| "続けて", "再開" | `run` (resume) | PAUSED |
| "止めて", "ストップ" | `stop` | RUNNING/PAUSED or pending_patch |
| "ちょっと待って", "一時停止" | `pause` | RUNNING only |
| "状況は？", "進捗" | `status` | any |
| "ヘルスチェック", "検査" | `doctor` | any |
| "更新して", "アップデート" | `update` (mutating — confirm always) | host_mode != plan-only |
| "ロールバック", "前のバージョンに" | `update --rollback` (destructive) | post-update only |
| "今何で詰まってる？", "ブロッカーは？" | `incident show <active_blocking_incident_id>` | any |
| "インシデント一覧", "エラー一覧" | `incident list` | any |
| "再試行", "リトライ" | `incident resolve <id> retry` | active blocking incident |
| "ワーカー切り替え", "別のワーカー" | `incident resolve <id> switch_worker` | active blocking incident |
| "日本語モード", "ja を有効化" | `/dtd locale enable ja` | any |
| "ロケール一覧" | `/dtd locale list` | any |
| "英語のみ", "ロケール無効" | `/dtd locale disable` | any |

## Pack contract

- Same contract as `ko.md`: required `## Slash aliases` and
  `## NL routing additions` sections, ≤ 8 KB, no canonical
  redefinition, audit in canonical English.
- This is a **seed** pack for v0.2.0e R0. Full NL coverage
  (attention/decision/perf/context-pattern/state-disambig variants)
  arrives in v0.2.0e R1 or later.

## See also

- `.dtd/locales/ko.md` — full pack template; ja R1 will mirror it.
- `dtd.md` §`/dtd locale` — command spec.
