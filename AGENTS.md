# Agent Working Rules (Project-Specific)

## 1) 적용 우선순위와 범위 (Core)

- 이 파일은 이 저장소 에이전트 정책의 코어 정본이다.
- 동일 규칙은 규칙군(R1~R7)에서 한 번만 정의한다. 다른 섹션은 링크/요약만 허용한다.
- 게임플레이/UI/씬/스크립트/리소스/프로젝트 설정 변경 작업에 본 정책을 적용한다.
- 환경 경로, 긴 실행 예시, 과거 이슈 메모는 참고 문서로 분리한다.

## 2) R1. Editor-First + Script Responsibility Boundary (Mandatory)

### Godot Workflow Priority

1. Editor-first instructions
- Godot 에디터에서 먼저 설정할 내용을 안내한다. (노드 선택, 씬 트리 작업, Inspector 값, 리소스 연결, 저장)
- 스크립트 설명보다 에디터 절차를 항상 먼저 제시한다.
- 에디터에서 설정 가능한 값은 에디터에서 먼저 작성한다.

2. Script-second instructions
- 에디터 설정 이후에 필요한 최소 스크립트만 설명한다.
- 스크립트는 트리거/기능 로직 범위로 제한한다.
- 사용자가 런타임 override를 명시적으로 요청하지 않은 한, Inspector/에디터 값 override를 금지한다.

### Editor-Authoritative Policy

- 에디터를 authorable data의 단일 소스로 간주한다.
- 아래 항목은 기본적으로 스크립트가 아니라 에디터에서 작성한다.
- node hierarchy / scene composition
- Inspector-authored 값 및 리소스 참조
- `SpriteFrames`, animation name/FPS/loop/autoplay
- 비주얼/오디오/콜리전 설정
- 스크립트에서 editor-authored 데이터 구조를 런타임 생성으로 대체하지 않는다.

### Script Responsibility Boundary

- 스크립트 허용 범위:
- 상태 전이 트리거 (`play_*` 호출 등)
- 신호 연결/처리
- 게임플레이 시스템 (spawn/combat/round rule)
- 이벤트 기반 런타임 반응
- 기본 금지 범위:
- 에디터에서 관리할 애니메이션 프레임 자산의 런타임 생성
- editor-authored animation data를 대체하는 하드코딩 테이블/FPS/loop
- animation/FPS/loop/autoplay를 스크립트에서 강제 override
- inspector-authored 값 무시/재설정

## 3) R2. Export Variable Description Policy (Mandatory)

- 모든 `@export* var`에는 Inspector에서 보이는 문맥을 제공한다.
- 새로 추가/수정한 export 필드는 같은 변경에서 아래 2가지를 동시에 적용한다.
- `@export_group`, `@export_subgroup`, `@export_category` 중 하나로 그룹화
- 변수 바로 위에 `##` doc comment 작성
- 설명은 목적/단위 문맥을 짧게 포함한다.
- 일반 주석(`# ...`)만으로 export 설명을 대체하지 않는다.

## 4) R3. Action Animation Restart Policy (Mandatory)

- 명시적 액션 트리거(`play_*`)는 동일 상태여도 기본적으로 대상 애니메이션을 재시작한다.
- 재시작은 에디터 리소스 수정이 아니라 스크립트 트리거 메서드에서 처리한다.
- 프레임 루프 기반 재시작은 frame-by-frame 요구가 명확할 때만 허용한다.
- 기본 적용 범위: Hero/Enemy의 attack, hurt, death, walk 트리거.
- 예외(재생 진행 유지가 필요한 액션)는 `TODO.md`에 근거를 기록한다.

## 5) R4. Implementation Design + OOP/Performance Gate (Mandatory)

### Responsibility Split

- 도메인/게임플레이 로직은 엔티티 스크립트가 담당한다. (예: `Enemy.gd`)
- UI 렌더링 로직은 UI 노드 스크립트가 담당한다. (예: `EnemyHealthBar.gd`)
- 엔티티가 UI 스타일/색/표현을 직접 제어하지 않는다.
- 엔티티 상태 변화는 신호(`health_changed`, `died` 등)로 방출하고 UI/시스템이 구독한다.

### Scene Inheritance Consistency

- base/variant 구조가 있으면 variant는 base를 인스턴스/상속한다.
- 공통 노드는 base scene에만 추가한다.
- variant는 필요한 override만 유지한다.
- base 변경 후 variant별 상속 노드 가시성/동작을 확인한다.

### OOP Principles

- SRP: 노드/클래스 하나는 하나의 책임만 가진다.
- Encapsulation: 상태 변경은 명시적 메서드(`take_damage()`, `heal()` 등)로만 허용한다.
- 외부에서 내부 상태를 직접 쓰는 코드(예: `enemy.hp -= 10`)를 금지한다.
- 상속 남용보다 컴포지션(노드 조합, 신호 협력)을 우선한다.

### Performance Principles

- `_process` / `_physics_process`는 프레임 단위 동작이 필수일 때만 사용한다.
- 이벤트/신호 기반으로 전환 가능한 로직은 폴링 대신 이벤트/신호를 우선한다.
- 핫패스에서 반복 `get_node*`, 동적 할당, 대형 배열 재생성, 과도한 문자열 포맷을 금지한다.
- 노드 참조는 `_ready()`에서 캐싱하고, 불변 값은 상수/초기화 1회 계산을 우선한다.
- 임시 오브젝트는 사용 후 `queue_free()`로 수명 관리를 명확히 한다.

### Definition of Done (Design/Perf)

- 기능 동작 확인
- 아키텍처 점검(책임 분리/상속 반영)
- 성능 점검(프레임 루프 필요성, 이벤트 대체 가능성, 핫패스 비용)
- 회귀 체크 포인트 문서화
- `TODO.md` 업데이트

## 6) R5. Godot CLI Validation Policy (Mandatory)

- Godot 개발 변경이 있을 때만 CLI 검증을 실행한다.
- Godot 개발 변경: `.tscn`, `.tres`, `.res`, `.gd`, `project.godot`, gameplay/UI/runtime 자산·설정 변경.
- 문서 전용 변경(`AGENTS.md`, `GAME_PLAN.md`, `TODO.md`, `README.md` 등)은 CLI 검증 대상이 아니다.
- CLI 결과는 응답에만 보고하고 `TODO.md`에는 기록하지 않는다.
- 응답 보고 형식: pass/fail, 사용 명령, 실패 시 핵심 에러 라인.
- WSL에서 `UtilBindVsockAnyPort ... socket failed 1`가 발생하면 PowerShell fallback으로 재시도한다.
- WSL/PowerShell 모두 실패하면 상태를 `CLI validation blocked`로 보고하고 가능한 대체 회귀 점검을 함께 기록한다.
- 명령 경로/예시는 참고 문서: `docs/reference/godot_cli_validation.md`

## 7) R6. Response Format + Godot UI Language Policy (Mandatory)

- Godot 설정/변경 요청 응답은 아래 순서를 고정한다.
1. `Editor에서 먼저 할 일`
2. `그 다음 스크립트`
- 위 순서를 뒤집지 않는다.
- 스크립트 섹션은 에디터 설정 이후 필요한 최소 트리거/기능 코드만 설명한다.
- Godot 4 UI 용어는 한국어 메뉴명을 우선한다. 필요 시 영어 라벨을 괄호로 병기한다.

## 8) R7. TODO/GAME_PLAN Workflow Policy (Mandatory)

### TODO-Driven Workflow

- 모든 작업은 `TODO.md`를 기준으로 진행한다.
- `TODO.md`는 당일/당주 활성 보드로 사용한다.
- 다음 날로 넘어가기 전, 완료 항목을 `docs/todo/YYYY-MM-Nw/YYYY-MM-DD.md`로 이관한다.
- 다음 날은 `TODO.md`를 다시 활성 보드로 갱신해 시작한다.
- `TODO.md` 갱신 시 과거 날짜 완료 섹션이 남아 있으면 해당 날짜 아카이브로 먼저 이동한다.

### GAME_PLAN Sync

- 게임플레이/UI/시스템 기능이 신규 구현되거나 동작이 바뀌면 같은 작업에서 `GAME_PLAN.md`를 갱신한다.
- 기능 구현 완료 기준에는 `TODO.md` + `GAME_PLAN.md` 동기화를 포함한다.

## 9) Game Concept (Current)

- Genre: Tower Defense
- Core loop: 캐릭터 모집/편성 -> 무기 장착/강화 -> 포털 스폰 적 처치

## 10) Reference Documents

- Godot CLI 실행 경로/명령/WSL fallback: `docs/reference/godot_cli_validation.md`
