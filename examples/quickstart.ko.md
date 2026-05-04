# DTD Quickstart — 30초 만에 Hello

가장 간단한 end-to-end 사용 예. 워커 1명, task 1개, 파일 1개.

언어 선택: [English](quickstart.md) · [日本語](quickstart.ja.md)

---

## 준비물

- agentic LLM (filesystem read/write **+** shell-exec 또는 web-fetch).
  Claude Code, Codex CLI, Cursor, OpenCode, Aider 등 다 됩니다.
- 워커 LLM endpoint 1개. 가장 간단한 건 로컬
  [Ollama](https://ollama.com) — `deepseek-coder:6.7b` 같은 모델.
  무료, 키 불필요, 네트워크 불필요.

---

## 1. 설치 (한 줄)

프로젝트 디렉토리에서 에이전트에게 한마디:

```text
github에서 daystar7777/dtd의 prompt.md 받아서 이 프로젝트에 설치해줘
```

에이전트가 부트스트랩을 받아 호스트 capability를 감지하고, `.dtd/` 트리를
만들고, `dtd.md`를 깔고, `CLAUDE.md` / `.cursorrules` / `AGENTS.md`에
한 줄 포인터를 추가합니다. 약 30초.

이렇게 보입니다:

```
✓ DTD installed.

  host_mode:      full
  DTD mode:       off (toggle on via /dtd mode on)
  Files written:  15 templates + dtd.md
  Host pointer:   appended to CLAUDE.md
  AIMemory:       absent (optional, see recommendation)
```

---

## 2. 첫 워커 등록

```text
/dtd workers add
```

대화형 프롬프트. 로컬 Ollama 기준:

```text
worker_id (kebab-case):     deepseek-local
endpoint:                    http://localhost:11434/v1/chat/completions
model:                       deepseek-coder:6.7b
api_key_env:                 OLLAMA_API_KEY
max_context (tokens):        32000
capabilities (csv):          code-write, code-refactor
aliases (csv, optional):     딥시크
tier (1-3):                  1
permission_profile:          code-write
escalate_to (worker | user): user

✓ Added worker 'deepseek-local' (aliases: 딥시크). Registry now has 1 worker.
```

또는 자연어로:

```text
"딥시크 워커 추가해줘. localhost:11434, code-write."
```

env var 설정:

```bash
export OLLAMA_API_KEY=ollama   # Ollama는 실제 키 불필요
```

---

## 3. 워커 점검

```text
/dtd workers test deepseek-local
```

기본 연결 점검입니다. env var, endpoint, auth, model이 짧은 호출에서
정상 동작하는지 확인합니다. 실패하면 env / endpoint / auth를 먼저 고친 뒤
계속하세요. 나중에 `/dtd run`은 이 워커에게 task를 보냅니다.

```text
✓ deepseek-local      OK     1.2s    parseable response
```

> 단계별 상세 로그와 추가 플래그 (`--all`, `--full`, `--connectivity`)는
> v0.2.1 Runtime Resilience에서 제공됩니다. 지금의 기본 probe는
> env / endpoint / auth / model 확인용입니다.

---

## 4. DTD 모드 켜기

```text
/dtd mode on
```

호스트 LLM("컨트롤러")이 매 turn마다 `.dtd/instructions.md`를 로드하기
시작합니다. 자연어 명령이 라우팅됩니다.

---

## 5. Plan → approve → run

```text
/dtd plan "src/hello.js에 hello-world 엔드포인트 추가"
```

컨트롤러가 DRAFT plan을 만들고 워커 할당을 보여줍니다:

```
+ plan-001 [DRAFT]
| goal: src/hello.js에 hello-world 엔드포인트 추가
+ tasks
| Task | Goal                       | Worker  | Work paths | Output paths   | Assigned via
| 1.1  | hello-world endpoint 구현   | 딥시크  | src/       | src/hello.js   | capability:code-write
+ phases
| phase 1: implement  workers: 딥시크  touches: src/

— Approve as-is:  /dtd approve
— Swap worker:    /dtd plan worker <task_id|phase:N|all> <worker>
— Re-plan:        /dtd plan <new goal>
```

계획 OK?

```text
/dtd approve
/dtd run
```

대시보드:

```
+ DTD plan-001 [RUNNING] phase 1/1 implement | iter 1/2 | NORMAL < GOOD | ctx 4% | total 5s
| current   1.1 hello-world endpoint 구현
| worker    deepseek-local (tier 1) profile=code-write
| work      src/
| writing   src/hello.js (live)
| locks     write files:project:src/hello.js
| elapsed   total 5s | phase 5s | task 5s
+ pause: /dtd pause  or  "잠깐 멈춰"
```

몇 초 후:

```
+ DTD plan-001 [COMPLETED] grade=GOOD | total 12s
| 1.1 hello-world endpoint 구현  [딥시크]  src/hello.js  GOOD  12s

✓ run-001 done. Summary: .dtd/log/run-001-summary.md
✓ Notepad archived: .dtd/runs/run-001-notepad.md
```

---

## 6. 끝

`src/hello.js` 파일이 생겼습니다. 열어보면 워커의 출력입니다.

이제:

- `/dtd plan "<다음 목표>"` — 다음 작업
- `/dtd workers add` — 워커 더 등록
- `/dtd status` — 언제든 현재 상태
- `/dtd doctor` — 헬스 체크
- `/dtd uninstall --soft` — 깨끗히 OFF (`.dtd/` 보존)

---

## 방금 일어난 일

1. **컨트롤러** (호스트 LLM)가 phase별 plan을 짜고 사용자 승인 요청.
2. approve 후 컨트롤러가 task 1.1을 **워커** (`deepseek-local`)에게 HTTP 디스패치 → 응답 대기.
3. 컨트롤러가 워커 출력 paths를 permission/lock 정책에 검증 → 통과 → 파일 적용.
4. COMPLETED 시 `finalize_run`이 notepad archive, summary 작성, lease 해제, state 갱신.
5. AIMemory 있으면 `WORK_START` + `WORK_END` 2개 이벤트만. 끝.

오케스트레이션 서버 없음. SDK 없음. SaaS 없음. `.dtd/` 안의 마크다운 + task당 HTTP 1회.

---

## 다음 단계

- **리뷰어 워커 추가** — cross-LLM 파이프라인 (작성자 → 리뷰어 → 수정자):
  `/dtd workers add` 시 `capabilities: review` + 다른 모델.
- **진행 중 방향 전환**: `"이번엔 안정성 우선"` → patch가 만들어지고 사용자 confirm.
- **멀티 phase plan**: [plan-001.md 예시](plan-001.md)에 5-phase + parallel-group + cross-vendor 파이프라인 데모.
- **풀스펙**: [dtd.md](../dtd.md) (~22 KB, 모든 canonical action).
- **컨트롤러 행동 규칙**: [.dtd/instructions.md](../.dtd/instructions.md).

[메인 README로 돌아가기](../README.ko.md).
