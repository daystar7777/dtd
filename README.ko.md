# DTD (Do Till Done)

> 비싼 LLM은 지휘만, 싼 LLM들이 일을 합니다.
> 마크다운만으로 만드는 멀티-LLM 협업 모드.

[English README](README.md) · [日本語 README](README.ja.md)

---

## 왜 필요한가요?

좋은 에이전트는 많습니다 — Claude Code, Codex, Cursor, Antigravity, Aider.
하지만 한 번에 하나만 씁니다. 토큰은 금방 닳고, task마다 잘하는 모델이 다릅니다.

DTD는 호스트 LLM을 **컨트롤러**로 바꿉니다.
계획을 짜고, 사용자 승인을 받고, 각 task를 **워커 LLM**에게 디스패치합니다.

Codex로 설계, DeepSeek로 구현, GPT-Codex로 리뷰, 다시 DeepSeek로 수정 —
한 plan, 한 명령.

서버도 SDK도 클라우드도 필요 없습니다. `.dtd/` 폴더 하나면 끝.

---

## 설치

쓰던 에이전트 — 어느 에이전트든 — 에게 한 줄 던지세요.

```text
github에서 daystar7777/dtd의 prompt.md 받아서 이 프로젝트에 설치해줘
```

에이전트가 호스트 capability를 감지하고, `.dtd/` 트리를 만들고,
슬래쉬 명령을 호스트별 적합 위치에 설치하고,
`CLAUDE.md` / `.cursorrules` / `AGENTS.md`에 한 줄 포인터를 추가합니다.

→ **그냥 한번 써보고 싶으세요?** [30초 Quickstart](examples/quickstart.ko.md)에서 설치 → 첫 plan → 첫 run까지 워커 1명으로 따라해볼 수 있습니다.

---

## 어떻게 쓰나요?

슬래쉬 — 세 그룹: **시작 / 관찰 / 복구**.

시작 (Start):

```text
/dtd workers add                 워커 LLM 등록
/dtd workers test <id>           기본 연결 점검 (env / endpoint / auth)
/dtd mode on                     DTD 모드 켜기
/dtd plan "API 추가하자"          phase별 계획 생성 (DRAFT)
/dtd approve                     계획 락-인
/dtd run                         실행
```

관찰 (Observe):

```text
/dtd status                      대시보드
/dtd plan show                   현재 계획 상세
/dtd doctor                      건강 체크
/dtd workers list                등록된 워커 목록
```

복구 (Recover, v0.2.0a Incident Tracking):

```text
/dtd pause                       다음 task 경계에서 멈춤
/dtd incident list               지금 막힌 거 목록
/dtd incident show <id>          상세 실패 이유 + 복구 옵션
/dtd incident resolve <id> retry 복구 옵션 선택
/dtd stop                        강제 종료 (destructive)
```

> 워커 헬스체크 상세 진단 (`--all`, `--full`, `--connectivity`, 단계 로그,
> 실패 분류) 은 v0.2.1 Runtime Resilience에서 출시.

또는 그냥 자연어로:

```text
"딥시크 워커 추가해줘"
"이 목표로 계획 짜줘"
"좋아 진행"
"잠깐 멈춰"
"task 3은 큐엔으로 바꿔"
"어디까지 됐어?"
```

같은 동작, 다른 인터페이스.

---

## 어떻게 보이나요?

### 설치 confirm 화면

```
DTD install plan:
  host_mode:   full     (감지: shell-exec + filesystem rw)
  DTD mode:    off      (나중에 /dtd mode on 으로 켜기)
  AIMemory:    not detected — 권장
  Files to fetch:
    - dtd.md (슬래쉬 명령)
    - .dtd/ × 15 templates
    - host pointer block → CLAUDE.md
Proceed? (y/n)
```

부트스트랩이 호스트 capability 먼저 감지한 후 사용자 confirm을 받습니다.
`host_mode`는 호스트 능력으로 고정 (plan-only / assisted / full), `DTD mode`는
사용자가 나중에 켜고 끄는 토글. AIMemory는 선택 — 없어도 DTD 작동.

### 워커 할당이 보이는 plan

`/dtd plan "user CRUD endpoints 추가"` 후:

```
+ plan-001 [DRAFT]
| goal: user CRUD endpoints 추가 (POST/GET/PATCH/DELETE /users)
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

각 task가 어떤 워커에게 가는지 **그리고 왜** (`Assigned via` 컬럼) 한눈에.
plan은 DRAFT — `/dtd approve` 전엔 아무것도 실행 안 됨. 승인 전에 자유롭게
워커 swap 가능 (`/dtd plan worker 3.1 deepseek` 또는 NL: "리뷰는 큐엔으로").

### Run 대시보드 (실시간)

`/dtd run` 후:

```
+ DTD plan-001 [RUNNING] phase 2/3 backend | iter 1/3 | NORMAL < GOOD | gate pending | ctx 42% | total 8m
| goal      user CRUD endpoints 추가
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
+ pause: /dtd pause  or  "잠깐 멈춰"
```

진행 따라 대시보드 갱신. grade, gate, context 사용량, 잡고 있는 lock,
elapsed time, 끝낸 거, 큐. 언제든 pause — in-flight task 깔끔히 마치고 멈춤.

### Doctor (헬스 체크)

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

`/dtd doctor`가 "지금 다 정상이야?" 명령. 워커 레지스트리 문제, stale lease,
시크릿 누출, 누락 템플릿, mode 불일치 검출. 자동 수정 안 함 — 뭐가 문제고
어떻게 처리하라고 알려줌.

---

## 무엇이 다른가요?

**멀티 LLM 라우팅**. 워커마다 capability / cost / tier를 적어두면 task 자동 분배.
cross-vendor 파이프라인이 한 plan에 들어갑니다.

**Tier escalation**. 워커 A가 3번 실패하면 자동으로 B로 → reviewer 추가 →
컨트롤러 직접 → 사용자 호출. 임계값은 워커마다 따로 설정.
같은 blocker 2회는 hash로 감지해 다음 단계로 가속.

**상태 머신 + 승인 게이트**. plan은 항상 DRAFT로 시작. 사용자 approve해야 RUNNING.
도중 변경(steering)은 patch가 되고, medium/high 임팩트면 다시 confirm.

**Pause / Resume / Stop**. RUNNING 중 멈출 수 있고, in-flight task는 깔끔히 완주.
다음 세션에서 이어서 가능. 작업 폴더 / 결과 폴더가 plan / status / history에 일관 표시.

**토큰 절약**. 워커 출력은 log 파일에, 채팅엔 한 줄 status. 완료 task 1줄 압축.
provider prompt cache 친화 정렬. status 출력 다이어트.

**보안 first-class**. API 키는 `.env`에만, 어디에도 echo 안 함.
`doctor`가 정규식으로 leak 검출.

**Mode 솔직**. 3-mode:

- `plan-only` — filesystem만, 워커 호출은 사용자가 manual paste
- `assisted` — shell 또는 web-fetch로 자동 디스패치, 필요 시 per-call confirm
- `full` — 자율 디스패치, 파괴적 액션만 confirm

`/dtd doctor`가 현재 호스트 capability + mode 보고.

---

## 어떤 환경에서?

호스트와 결합 없음. filesystem read/write 가능하면 설치됩니다.
shell-exec 또는 web-fetch가 추가로 있으면 워커 자동 디스패치까지.

지원 호스트: Claude Code, ChatGPT Codex CLI, OpenCode, Cursor, Antigravity,
Aider, Cline, Continue, Windsurf, gemini-cli, 그 외 agentic harness.

워커 endpoint: OpenAI-호환이면 모두 — 로컬 (Ollama, vLLM, LM Studio, llama.cpp),
원격 (OpenAI, OpenRouter, DeepSeek API, Hugging Face Inference, Anthropic-compat shim).

선택 통합: [agent-work-mem](https://github.com/daystar7777/agent-work-mem)
— 멀티 세션 작업 이력. DTD가 자동 감지해서 최소한으로 사용 (run당 1쌍 + 5개 예외).

---

## 무엇이 만들어지나요?

```
프로젝트 루트/
├── 코드들/
├── CLAUDE.md (또는 호스트별 등가)     ← DTD 포인터 한 줄 추가
├── dtd.md                              ← 슬래쉬 명령 source
└── .dtd/
    ├── instructions.md                 ← 컨트롤러 행동 spec
    ├── config.md                       ← 글로벌 설정
    ├── workers.example.md              ← 스키마 + endpoint 예시 (커밋됨)
    ├── workers.md                      ← 실제 레지스트리 (gitignored, 로컬 전용)
                                           install 시 workers.example.md 복사로 생성됨
    ├── worker-system.md                ← 워커 출력 discipline
    ├── resources.md                    ← active lock/lease
    ├── state.md                        ← 런타임 상태
    ├── steering.md                     ← 사용자 지시 이력
    ├── phase-history.md                ← phase 로그
    ├── PROJECT.md                      ← 프로젝트 컨텍스트 capsule
    ├── notepad.md                      ← run당 wisdom (워커에게 handoff)
    ├── plan-NNN.md                     ← /dtd plan 시 생성
    ├── log/                            ← 워커 호출 raw 로그
    ├── attempts/                       ← immutable attempt timeline
    ├── runs/                           ← archived run notepads
    ├── eval/                           ← phase eval (retry 시)
    └── skills/{code-write,review,planning}.md
```

---

## 이런 사람에게 좋습니다

- 컨트롤러(Claude/Codex)가 plan, 로컬 워커(DeepSeek/Qwen)가 구현하고 싶을 때
- vendor 다른 LLM들로 파이프라인 만들기 (작성자 ≠ 리뷰어 ≠ 수정자)
- 며칠 걸리는 multi-phase 작업 — 세션 가로질러 pause/resume 필요
- AI 변경 사항을 감사 로그로 남기고 싶은 팀
- 에이전트끼리 컨텍스트 복붙이 지긋지긋한 사람
- **이미 phase로 진행 중인 프로젝트에 DTD 적용** — 설치 후 done 표시만 하면 DTD가 남은 작업부터 이어받음. 3가지 패턴이 [dtd.md §Adopting DTD](dtd.md#adopting-dtd-on-existing-in-progress-work)에 있습니다.

---

## v0.1에 *없는* 것

- DTD 인스턴스 간 분산 lock 보장 (global path는 best-effort)
- streaming worker response
- Anthropic Messages / Gemini API 직접 어댑터 (OpenAI-호환 shim 권장)
- 보팅 / 합의 디스패치 (한 task = 한 워커)
- `.dtd/runs/` archive search
- `/dtd runs prune` cleanup 명령

v0.2 / v0.1.1 로드맵에 있습니다.

---

## 한 줄로 요약

> 컨트롤러는 짜고, 워커는 하고, 사용자는 운전한다.
> **Do till done. 끝날 때까지 한다.**
