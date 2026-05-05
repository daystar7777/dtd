# DTD Locale Pack: ko (Korean)

> Optional pack. Loaded by controller AFTER `.dtd/instructions.md`
> when `config.md locale.enabled: true` AND `state.md locale_active: ko`.
>
> Augments core English-only NL routing. NEVER replaces canonical
> commands; canonical actions are still recorded in `state.md` /
> `attempts/run-NNN.md` / log files in English.

## Pack metadata

- locale: ko
- name: Korean
- version: v0.2.0e (R1 NL additions for v0.2.0b + v0.2.0c)
- merge_policy: pack_wins_on_conflict
- size_budget_kb: 12

## Slash aliases

```
/ㄷㅌㄷ <args>     Korean initial-consonant alias
/디티디 <args>    full Korean alias
```

Routing: detect prefix → strip → normalize to canonical `/dtd` → feed
remainder through Intent Gate. Audit entries always record
`/dtd <action>`, never the Korean spelling.

## NL routing additions

Augments the Intent Gate. Pack-wins on conflict.

| Korean phrase pattern | Canonical | Required state |
|---|---|---|
| "계획 짜줘", "이 목표로 정리", "이거 어떻게 할까" | `plan <inferred goal>` | any (DRAFT overwrite confirms) |
| "좋아 진행", "ok 시작", "그대로 가" | `approve` | DRAFT only |
| "실행해", "돌려", "시작" | `run` | APPROVED or PAUSED |
| "이어서", "계속해" | `run` (resume) | PAUSED |
| "3페이즈까지만 해줘", "phase 3까지 돌려" | `run --until phase:3` | APPROVED or PAUSED |
| "리뷰 전까지만 돌려" | `run --until before:review` | APPROVED or PAUSED |
| "UI 만들고 멈춰", "task X끝나면 멈춰" | `run --until task:<id>` | APPROVED or PAUSED |
| "다음 결정나오면 멈춰" | `run --until next-decision` | APPROVED or PAUSED |
| "잠깐", "멈춰", "기다려" | `pause` | RUNNING only |
| "그만", "취소", "관둬" | `stop` | RUNNING/PAUSED or pending_patch |
| "지금 어디까지", "진행상황", "어떻게 돼가" | `status` | any |
| "처음 계획 보여줘", "계획 다시 보여줘" | `plan show` | any (after plan exists) |
| "task N은 X로", "phase N은 X가" | `plan worker` (DRAFT) or `steer` (post-DRAFT) | DRAFT swap; else patch |
| "워커 추가", "X 등록" | `workers add` | any |
| "X 빼줘", "워커 제거" | `workers rm` | any |
| "X에 별명 Y", "Y로 부를게" | `workers alias add` | any |
| "리뷰어를 X로", "primary는 Y로" | `workers role set` | any |
| "방향 바꾸자", "이번엔 안정성 우선" | `steer <text>` | RUNNING/APPROVED/PAUSED |
| "patch 적용", "그 변경 가" | `steer approve patch` | pending_patch |
| "patch 빼", "그 변경 안 해" | `steer reject patch` | pending_patch |
| "DTD 꺼", "일반모드", "그냥 너가 해" | `mode off` | any |
| "DTD 켜", "협업모드" | `mode on` | any |
| "건강 체크", "검사" | `doctor` | any |
| "지워", "삭제" | `uninstall` | any (off first if running) |
| "도움말", "어떻게 써?" | `help` (no arg) | any |
| "워커 도움말" | `help workers` | any |
| "막혔을 때" | `help stuck` | any |
| "업데이트 해줘", "최신으로 업데이트" | `update` (mutating — confirm always) | host_mode != plan-only |
| "업데이트 미리보기" | `update --dry-run` | any |
| "버전 확인", "최신 버전 뭐야" | `update check` | any |
| "롤백", "이전 버전으로" | `update --rollback` (destructive — confirm) | post-update only |
| "지금 막힌 거 뭐야", "어디서 막혔어?", "어떤 에러야" | `incident show <active_blocking_incident_id>` (or `incident list`) | any |
| "incident 목록", "에러 목록", "사고 보여줘" | `incident list` | any |
| "incident <id> 보여줘", "그 사고 자세히" | `incident show <id>` | any |
| "그 에러 재시도", "재시도로 가자" | `incident resolve <id> retry` | active blocking incident |
| "워커 바꿔서 다시", "다른 워커로" | `incident resolve <id> switch_worker` | active blocking incident |
| "incident <id> 그만", "그 에러 멈춰" | `incident resolve <id> stop` (DESTRUCTIVE — always confirm) | active blocking incident |

### Attention / decision mode

| Korean phrase pattern | Canonical | Required state |
|---|---|---|
| "자러갈게 4시간 조용히 개발해줘", "몇 시간 동안 조용히 진행해줘" | `/dtd run --silent=<duration>` or `/dtd silent on --for <duration>` | APPROVED/PAUSED/RUNNING |
| "4시간 자동진행, 조용히", "질문하지 말고 가능한 것만 해" | `/dtd run --decision auto --silent=<duration>` | APPROVED/PAUSED |
| "큰 결정은 물어보고 진행해" | `/dtd mode decision permission` | any |
| "계획 단위로만 물어봐" | `/dtd mode decision plan` | any |
| "자동진행 모드로" | `/dtd mode decision auto` | any |
| "이제 물어보면서 해", "인터랙티브 모드" | `/dtd interactive` | any |

### Perf / context-pattern / locale management

| Korean phrase pattern | Canonical |
|---|---|
| "토큰 사용량 보여줘", "페이즈별 토큰 체크" | `/dtd perf --tokens` |
| "워커별 퍼포먼스 보여줘", "워커 토큰 얼마나 썼어" | `/dtd perf --worker all --tokens` |
| "비용 보여줘", "페이즈별 비용/토큰" | `/dtd perf --cost --tokens` |
| "이번 설계 페이즈는 탐색적으로 해", "explore 패턴으로" | set `context-pattern="explore"` (DRAFT edit; else steer) |
| "구현은 안정적으로 fresh로 가자", "결정적으로 해" | set `context-pattern="fresh"` |
| "이 에러는 디버그 패턴으로 다시 돌려", "debug로 재시도" | retry with `context-pattern="debug"` |
| "한국어 켜", "한국어 모드" | `/dtd locale enable ko` |
| "로케일 보여줘", "어떤 언어 켜져있어" | `/dtd locale list` |
| "영어로만 해", "로케일 꺼" | `/dtd locale disable` |

### Permission ledger (v0.2.0b)

| Korean phrase pattern | Canonical |
|---|---|
| "src/ 자유롭게 편집" | `/dtd permission allow edit scope: src/**` |
| "npm test 자동으로" | `/dtd permission allow bash scope: npm test` |
| "rm -rf 절대 금지" | `/dtd permission deny bash scope: rm -rf` |
| "데이터 폴더는 매번 물어봐" | `/dtd permission ask external_directory scope: ~/data/**` |
| "권한 보여줘", "퍼미션 목록" | `/dtd permission list` |
| "그 권한 빼", "권한 취소" | `/dtd permission revoke <key> scope: <expr>` |

### Snapshot / revert (v0.2.0c)

| Korean phrase pattern | Canonical |
|---|---|
| "되돌려", "취소하고 이전 상태로" | `/dtd revert last` |
| "<task> 되돌려" | `/dtd revert task <id>` |
| "방금 변경 되돌려" | `/dtd revert last` |
| "되돌릴 수 있어?" | `/dtd snapshot list --task <current>` |
| "스냅샷 보여줘" | `/dtd snapshot list` |
| "오래된 스냅샷 정리" | `/dtd snapshot rotate` |

## State-aware Disambiguation phrase additions

Rules from `instructions.md` unchanged; pack adds Korean phrase
variants: "좋아"/"그대로"/"진행해"/"갈게" (OK), "잠깐" (pause),
"재시도"/"다시" (retry), "그 에러"/"그 사고" (incident referent),
"조용히"/"자러갈게" (silent), "인터랙티브" (exit silent),
"자동"/"물어보지 마" (decision auto).

## Confirmation phrasing (Korean)

Per `instructions.md` §Confidence & Confirmation, use Korean
phrasing for confirm questions, e.g.:
`"approve 하고 곧장 run까지 가는 걸로 이해했어요. 맞나요? (y/n)"`,
`"진짜 stop 할까요? plan-001은 STOPPED로 마감됩니다. (y/n)"`.

## Output translations (selected)

User-facing output strings. Core English text remains canonical in
logs / state / attempts.

| key | Korean (this pack) |
|---|---|
| `silent_on_confirm` | "조용히 모드 켜짐 (until <ts>, '<goal>'). 잠자리 잘 다녀와." |
| `interactive_no_deferred` | "인터랙티브 모드. 보류된 블로커 없음. /dtd run 으로 재개." |
| `locale_enabled` | "로케일 'ko' 활성화. 한국어 NL 라우팅 사용 중." |
| `locale_disabled` | "로케일 비활성화. 영어 코어만 사용." |
| `locale_pack_missing` | "로케일 '<lang>' 파일이 없습니다: .dtd/locales/<lang>.md" |
| `bootstrap_hint` | "한국어 로케일이 꺼져 있어요. `/dtd locale enable ko` 로 켜주세요." |

## Pack contract

- MUST contain `## Slash aliases` and `## NL routing additions`
  (validated by `/dtd doctor` v0.2.0e
  `locale_pack_missing_required_section`).
- MUST be ≤ 12 KB; over → WARN `locale_pack_oversized`.
- MUST NOT redefine canonical commands.
- All audit fields record CANONICAL English forms.

## See also

- `dtd.md` §`/dtd locale` and §`/dtd permission`.
- `.dtd/instructions.md` §"Locale bootstrap aliases".
- `.dtd/reference/doctor-checks.md` §"Locale state (v0.2.0e)".
