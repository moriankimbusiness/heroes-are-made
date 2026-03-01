---
name: task-plan-md
description: Create or update docs/tasks/<task-name>/plan.md for detailed execution plans. Enforce AI-only implementation phases, code snippets, and user-only manual QA/debug checklist.
---

# Task Plan MD

Create and maintain `docs/tasks/<task-name>/plan.md`.

## Workflow

1. Determine `<task-name>` in lowercase kebab-case.
- Prefer explicit user-provided slug.
- Normalize `docs/tastks` typo to `docs/tasks`.

2. Ensure related research link.
- If present, link `docs/tasks/<task-name>/research.md` at the top.

3. Create `plan.md` if missing.
- Use `scripts/create_plan_md.sh <task-name>`.
- If the file exists, update progress/checklist instead of replacing the whole file.

4. Keep execution structure explicit.
- 목표
- 범위 (In/Out)
- 구현 컨텍스트
- 단계별 작업 (AI Coding Assistant 전용)
- 단계별 코드 스니펫
- 검증 체크리스트 (사용자 수동 QA 전용)
- 디버그 테스트 가이드
- 리스크/대응
- 완료 선언 조건

5. Mark completion in the plan document.
- Add a clear completion status line with date.
- Convert checklist items to `[x]` when done.

## Execution Ownership Rule (Mandatory)

- `단계별 작업 (Phase)`에는 AI Coding Assistant가 수행할 구현/편집/검증 자동화 작업만 작성한다.
- 사용자(사람) 수동 확인/테스트/리뷰 항목은 Phase에 작성하지 않는다.
- 사용자 검증은 반드시 `검증 체크리스트` 섹션에만 작성한다.

## Snippet Requirement Rule (Mandatory)

- 각 주요 Phase마다 최소 1개 이상의 코드 또는 명령 스니펫을 포함한다.
- 스니펫에는 아래 문맥을 함께 적는다.
- 대상 파일 경로 또는 실행 위치
- 적용 목적
- 기대 결과
- Godot 작업일 경우 가능하면 노드 경로/신호명/관련 씬 경로를 함께 명시한다.

## Manual QA Checklist Rule (Mandatory)

- `검증 체크리스트`는 사용자 수동 QA 전용이다.
- 단순 체크박스만 쓰지 말고, 테스트케이스 단위로 상세 절차를 작성한다.
- 기본 필드:
- 테스트 ID
- 사전조건
- 검증 절차(번호 순서)
- 기대 결과
- 실패 시 디버그 방법(로그 키워드, 확인 노드/신호, 재현 조건)

## Debugability Rule (Mandatory)

- `디버그 테스트 가이드`를 항상 포함한다.
- 공통 관찰 포인트(Output 로그, Inspector/Remote SceneTree, 신호 수신 여부)를 적는다.
- 증상별 분기(무반응, 값 불일치, null 참조 등)와 확인 순서를 명시한다.

## Planning Depth Standard

- Plan deeply, not at a high-level summary only.
- Break work into concrete phases, each with explicit deliverables and completion criteria.
- Include detailed sub-tasks that are directly executable and verifiable.
- Capture dependencies, ordering constraints, risks, fallback paths, and regression checks.
- Define measurable validation checkpoints for each major step.
- State assumptions and unresolved questions explicitly; add how to resolve them.
- Include exact file paths, target artifacts, and expected state changes whenever possible.

## Guardrails

- Keep plan content in `docs/tasks/<task-name>/plan.md` unless the user asks otherwise.
- Keep step descriptions concrete and testable.
- Keep language aligned with the user's request. Default to Korean when user writes in Korean.
