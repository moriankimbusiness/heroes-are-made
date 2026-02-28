# 결과: AGENTS.md 통합 정리 실행 보고

날짜: 2026-02-28  
기준 계획: `docs/tasks/agents-md-governance-review-2026-02-28/plan.md`

## Phase 0. 의무 문장 인벤토리 (원본 기준)

원본 기준 파일: `git show HEAD:AGENTS.md`  
ID 형식: `POL-001`

| ID | 규칙군 | 원본 라인 | 요약 |
|---|---|---:|---|
| POL-001 | R1 | 5 | Godot 설정 요청은 Editor-first -> Script-second 순서를 강제 |
| POL-002 | R1 | 10 | 에디터에서 설정 가능한 값은 에디터에서 먼저 작성 |
| POL-003 | R1 | 14 | 명시적 요청 없으면 스크립트가 editor-authored 값을 override 금지 |
| POL-004 | R1 | 19 | editor를 authorable data 단일 소스로 취급 |
| POL-005 | R1 | 20-25 | 구성 가능한 데이터(씬/Inspector/애니메이션/비주얼/오디오/콜리전)는 에디터 우선 |
| POL-006 | R1 | 29-38 | 스크립트는 trigger/feature 로직 한정, 에디터 데이터 런타임 대체 금지 |
| POL-007 | R1 | 42-45 | animation/FPS/loop/autoplay 강제 override 금지 |
| POL-008 | R2 | 49-58 | export 필드는 그룹화 + `##` doc comment 동시 적용 |
| POL-009 | R3 | 62-64 | `play_*` 액션은 동일 상태여도 기본 재시작, 프레임 루프 재시작 금지 |
| POL-010 | R3 | 67 | 재생 진행 유지 예외는 `TODO.md`에 기록 |
| POL-011 | R4 | 74-77 | 엔티티/도메인과 UI 렌더 책임 분리, 신호 기반 상태 전달 |
| POL-012 | R4 | 80-83 | base/variant 상속 구조 일관성 유지 |
| POL-013 | R4 | 86-88 | 구현 순서: Editor 설정 후 Script, editor-authored override 금지 |
| POL-014 | R4 | 91-96 | DoD: 기능/아키텍처/성능/TODO/회귀/CLI 조건 점검 |
| POL-015 | R4 | 102-112 | OOP 원칙(SRP/캡슐화/컴포지션/신호 기반 의존 역전) |
| POL-016 | R4 | 118-132 | 최적화 원칙(핫패스 최소화/이벤트 우선/재계산 방지/수명 관리) |
| POL-017 | R4 | 140-148 | 프레임 루프 남용 금지, UI 이벤트 기반, 고비용 루프 작업 금지 |
| POL-018 | R5 | 159-162 | Godot 변경에만 CLI 검증, 문서 전용 변경 제외, CLI 결과는 응답에만 보고 |
| POL-019 | R5 | 175-180 | WSL socket 실패 시 PowerShell fallback, 양쪽 실패 시 blocked 처리 |
| POL-020 | R6 | 186-190 | 응답 섹션 순서 고정(`Editor에서 먼저 할 일` -> `그 다음 스크립트`) |
| POL-021 | R6 | 194-196 | Godot UI 메뉴명은 한국어 우선 |
| POL-022 | R7 | 209-221 | TODO 기반 운영/아카이브 흐름 강제 |
| POL-023 | R7 | 225-227 | gameplay/UI/system 변경 시 GAME_PLAN 동기화 |
| POL-024 | R5-ref | 231-238 | 실행 경로/환경 메모는 운영 참고 정보 |

## Phase 1. 규칙군 정본 선정

정본 위치는 새 `AGENTS.md`의 규칙군 섹션으로 고정했다.

- R1: `## 2) R1. Editor-First + Script Responsibility Boundary (Mandatory)`
- R2: `## 3) R2. Export Variable Description Policy (Mandatory)`
- R3: `## 4) R3. Action Animation Restart Policy (Mandatory)`
- R4: `## 5) R4. Implementation Design + OOP/Performance Gate (Mandatory)`
- R5: `## 6) R5. Godot CLI Validation Policy (Mandatory)`
- R6: `## 7) R6. Response Format + Godot UI Language Policy (Mandatory)`
- R7: `## 8) R7. TODO/GAME_PLAN Workflow Policy (Mandatory)`

## Phase 2. 구조 재설계 결과

### 전/후 지표

| 항목 | 기존 | 변경 후 |
|---|---:|---:|
| 줄 수 | 238 | 145 |
| 바이트 | 13,192 | 7,509 |
| H2 수 | 16 | 10 |
| 불릿 라인 수 | 142 | 82 |

핵심 실행 규칙 순서를 고정했다.

1. 적용 우선순위/범위
2. Editor-first + Script boundary
3. Validation/Definition of done
4. 응답 포맷/언어
5. 워크플로우(TODO/GAME_PLAN)

## Phase 3. 참고성 상세 분리

분리 문서 생성:

- `docs/reference/godot_cli_validation.md`

`AGENTS.md`에서는 아래 링크만 유지:

- `docs/reference/godot_cli_validation.md`

## Phase 4. 회귀/충돌 점검

### 인벤토리 커버리지

- POL-001 ~ POL-023: 모두 새 `AGENTS.md`의 R1~R7 정본 섹션에 매핑됨
- POL-024: 정책 본문에서 제거하고 참고 문서(`docs/reference/godot_cli_validation.md`)로 분리됨

### 충돌 검사 결과

- 동일 상황 상반 지시: 없음
- `only when` 조건 모호성: 없음
- CLI 검증 조건 단일 출처화: 완료(R5)

### 샘플 시나리오 점검

- 문서만 수정: CLI 검증 생략, TODO 갱신만 요구
- Godot 스크립트 수정: Editor-first 안내 + Script 최소화 + CLI 검증 요구
- Godot 씬 수정: Editor-authoritative 유지 + CLI 검증 요구
- 리서치/계획 문서 작업: R5 예외(문서 전용) 적용

## Phase 5. 마감 기록

- `TODO.md`에 본 작업 완료 이력 반영
- 계획 체크리스트 통과 상태 반영

## 계획 체크리스트 결과

- [x] `AGENTS.md` 줄 수 목표 범위(120~160) 근접
- [x] 중복 강제 문장 0건(규칙군 정본 단일화)
- [x] CLI 검증 정책 단일 출처화
- [x] TODO/GAME_PLAN 동기화 규칙 단일 위치 명시
- [x] 응답 형식/언어 규칙 분명화 및 중복 제거
- [x] 분리된 참고 문서 링크 정상 연결
