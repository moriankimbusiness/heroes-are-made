# Task Plan MD

`docs/tasks/<task-name>/plan.md` 실행 계획을 생성하거나 갱신한다.

## 입력

사용자 요청: $ARGUMENTS

## Workflow

1. **task-name 결정** — lowercase kebab-case.
   - 사용자가 명시한 slug 우선.
   - `docs/tastks` 오타는 `docs/tasks`로 정규화.

2. **디렉토리 생성** — `docs/tasks/<task-name>/` 없으면 생성.

3. **연결 리서치 링크** — `docs/tasks/<task-name>/research.md`가 존재하면 plan.md 상단에 링크.

4. **plan.md 생성 또는 갱신**
   - 파일이 없으면 `skills/task-plan-md/scripts/create_plan_md.sh <task-name>` 실행 후 내용 채움.
   - 파일이 이미 있으면 기존 내용을 보존하면서 진행 상태/체크리스트만 갱신.

5. **필수 섹션 구조**
   - 목표
   - 범위 (In/Out)
   - 단계별 작업 (Phase) — 구체적 하위 작업 포함
   - 검증 체크리스트
   - 리스크/대응
   - 완료 선언 조건

6. **완료 표시** — 완료 시 날짜와 함께 상태를 갱신하고 체크리스트 `[x]` 전환.

## Planning Depth Standard

- 고수준 요약이 아닌 **깊이 있는 계획** 작성.
- 각 Phase에 명확한 산출물과 완료 기준 포함.
- 하위 작업은 직접 실행·검증 가능한 수준까지 분해.
- 의존성, 순서 제약, 리스크, 대안 경로, 회귀 점검 포함.
- 주요 단계마다 측정 가능한 검증 체크포인트 정의.
- 가정과 미해결 질문을 명시하고 해결 방법 기술.
- 가능하면 정확한 파일 경로, 대상 산출물, 예상 상태 변화 포함.

## Guardrails

- 계획 내용은 `docs/tasks/<task-name>/plan.md`에 작성 (사용자가 다른 위치를 요청하지 않는 한).
- 단계 설명은 구체적이고 테스트 가능하게.
- 사용자가 한국어로 요청하면 한국어로 작성.
