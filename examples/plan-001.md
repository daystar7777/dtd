# DTD Example Plan — plan-001

> This is an EXAMPLE. Do not copy verbatim into your project.
> See `.dtd/plan-001.md` (created when you run `/dtd plan <goal>`).
> Showcases: brief, phases, tasks with workers/capabilities/paths/depends-on/parallel-group, patches.

<plan-status>RUNNING</plan-status>

<brief>
goal: e-commerce 백엔드 API + 프론트엔드 + 코드 리뷰 사이클 한 번
approach: 1) 데이터 모델 설계 → 2) backend 구현 → 3) frontend 구현 (병렬) → 4) cross-LLM 리뷰 → 5) 피드백 반영
non-goals: 결제 통합, 배포 자동화, 유닛 테스트 풀커버리지
target-grade-default: GOOD
</brief>

<phases>

  <phase id="1" name="planning" target-grade="GREAT" max-iterations="2">
    <task id="1.1" parallel-group="A">
      <goal>데이터 schema 설계 (User, Product, Order)</goal>
      <worker>qwen-remote</worker>
      <worker-resolved-from>role:planner</worker-resolved-from>
      <capability>planning</capability>
      <work-paths>docs/, src/types/</work-paths>
      <output-paths predicted="true">docs/schema.md</output-paths>
      <context-files>src/types/index.ts</context-files>
      <resources>
        <resource mode="write">files:project:docs/schema.md</resource>
      </resources>
      <done>true</done>
      <status>done</status>
      <grade>GREAT</grade>
      <duration>30s</duration>
      <log>exec-001-task-1.1.qwen-remote.md</log>
    </task>

    <task id="1.2" parallel-group="A">
      <goal>API 엔드포인트 명세 작성 (REST, OpenAPI 3)</goal>
      <worker>qwen-remote</worker>
      <worker-resolved-from>role:planner</worker-resolved-from>
      <capability>planning</capability>
      <work-paths>docs/</work-paths>
      <output-paths predicted="true">docs/api-spec.md</output-paths>
      <done>true</done>
      <status>done</status>
      <grade>GREAT</grade>
      <duration>40s</duration>
      <log>exec-001-task-1.2.qwen-remote.md</log>
    </task>
  </phase>

  <phase id="2" name="backend" target-grade="GOOD" max-iterations="3">
    <task id="2.1" depends-on="1.1,1.2">
      <goal>User CRUD endpoints 구현 (POST /users, GET /users/:id, etc.)</goal>
      <worker>deepseek-local</worker>
      <worker-resolved-from>capability:code-write</worker-resolved-from>
      <capability>code-write</capability>
      <work-paths>src/api/, src/types/</work-paths>
      <output-paths predicted="true">src/api/users.ts, src/api/users.test.ts</output-paths>
      <context-files>docs/schema.md, docs/api-spec.md, src/types/index.ts</context-files>
      <resources>
        <resource mode="write">files:project:src/api/**</resource>
        <resource mode="read">files:project:src/types/**</resource>
      </resources>
      <done>true</done>
      <status>done</status>
      <grade>GOOD</grade>
      <output-paths actual="true">src/api/users.ts, src/api/users.test.ts, src/api/users.helpers.ts</output-paths>
      <duration>8m12s</duration>
      <log>exec-001-task-2.1.deepseek-local.md</log>
    </task>

    <task id="2.2" depends-on="1.1,1.2">
      <goal>Product + Order CRUD endpoints</goal>
      <worker>deepseek-local</worker>
      <capability>code-write</capability>
      <work-paths>src/api/</work-paths>
      <output-paths predicted="true">src/api/products.ts, src/api/orders.ts</output-paths>
      <resources>
        <resource mode="write">files:project:src/api/**</resource>
      </resources>
      <done>false</done>
      <status>in-flight</status>
    </task>
  </phase>

  <phase id="3" name="frontend" target-grade="GOOD" max-iterations="3">
    <task id="3.1" depends-on="1.2" parallel-group="B">
      <goal>Product list 페이지 (React component + API call)</goal>
      <worker>deepseek-local</worker>
      <capability>code-write</capability>
      <work-paths>src/ui/</work-paths>
      <output-paths predicted="true">src/ui/ProductList.tsx</output-paths>
      <context-files>docs/api-spec.md</context-files>
      <done>false</done>
    </task>

    <task id="3.2" depends-on="1.2" parallel-group="B">
      <goal>Cart + Checkout 페이지</goal>
      <worker>deepseek-local</worker>
      <capability>code-write</capability>
      <work-paths>src/ui/</work-paths>
      <output-paths predicted="true">src/ui/Cart.tsx, src/ui/Checkout.tsx</output-paths>
      <done>false</done>
    </task>
  </phase>

  <phase id="4" name="review" target-grade="GREAT" max-iterations="2">
    <task id="4.1" depends-on="2.1,2.2,3.1,3.2">
      <goal>전체 변경사항 코드 리뷰 (cross-LLM, 다른 vendor가 검토)</goal>
      <worker>gpt-codex</worker>
      <worker-resolved-from>role:reviewer</worker-resolved-from>
      <capability>review</capability>
      <work-paths>src/api/, src/ui/</work-paths>
      <output-paths predicted="true">docs/review-001.md</output-paths>
      <done>false</done>
    </task>
  </phase>

  <phase id="5" name="feedback" target-grade="GOOD" max-iterations="unlimited">
    <!-- Demo: unlimited iterations until reviewer's P1 findings all resolved.
         Safety: gpt-codex.escalate_to=user (in workers.md) is the terminal,
         so genuinely stuck cases still bubble to user via failure_reason_hash
         even with unlimited cap. /dtd pause always works too. -->
    <task id="5.1" depends-on="4.1">
      <goal>리뷰 P1 findings 반영 (워커는 리뷰어가 아닌 원작성자)</goal>
      <worker>deepseek-local</worker>
      <capability>code-write</capability>
      <work-paths>src/api/, src/ui/</work-paths>
      <output-paths predicted="true">src/api/**, src/ui/**</output-paths>
      <context-files>docs/review-001.md</context-files>
      <done>false</done>
    </task>
  </phase>

</phases>

<patches>
  <!-- Example of a patch that came in mid-RUNNING (medium impact steering) -->
  <patch id="1" date="2026-05-04 21:15" impact="medium" steering-ref="steering.md#L13" status="approved">
    <change type="target-grade">phase 4 review: GOOD → GREAT (사용자가 리뷰 강도 높이라고 요청)</change>
    <reason>사용자 발화: "리뷰는 빡세게 봐줘"</reason>
    <applied-at>2026-05-04 21:15:42</applied-at>
  </patch>
</patches>

