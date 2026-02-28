# 계획: PlayGround 리팩토링 및 OOP 리스크 해소

날짜: 2026-02-28
연결 리서치: `docs/tasks/playground-role-2026-02-28/research.md`
계획 문서 상태: 작성 완료 (2026-02-28)
실행 상태: 부분 완료 (2026-02-28)
대상 릴리즈: 다음 전투 구조 정리 배치(단일 브랜치 연속 작업)

## 1) 목표
- `PlayGround` 주변의 리팩토링 우선순위를 "런타임 결합도/회귀 위험/OOP 위배도" 기준으로 정렬한다.
- UI 계층(`ShopPanel`, `HeroHUD`)에 남아있는 도메인 상태(골드/리롤/구매 규칙) 결합을 분리한다.
- 하드코딩 경로(`"PlayGround/..."`) 의존을 줄여 네이밍 변경 가능성과 구조 변경 내성을 높인다.
- `PlayGround`의 혼합 책임(도메인 오케스트레이션 + 표현 계산)을 분해해 SRP/캡슐화 정합성을 개선한다.

## 2) 범위
### In Scope
- 구조 리팩토링 계획 및 실행 대상 정의
- `scripts/playground/PlayGround.gd` 책임 분해
- `scripts/playground/ui/ShopPanel.gd`의 도메인 상태 분리
- `scripts/flow/screens/BattleSummaryCollector.gd` UI 경로 의존 제거
- `scripts/flow/screens/BattleScreenHost.gd`의 `PlayGround` 경로 결합 완화
- 필요 시 신규 도메인 서비스 파일 추가
- 관련 씬 경로/노드 경로 정리(`scenes/levels/level_base.tscn`, `scenes/playground/playground.tscn`)

### Out of Scope
- UI 비주얼 리디자인(레이아웃/아트/테마 변경)
- 밸런스 수치 재설계(아이템 가격, 리롤 비용 정책 자체 변경)
- 월드맵/노드 전용 화면 등 전투 외 플로우 개편
- 저장 포맷 버전 업(스키마 대수술)

## 3) 의존성 및 순서 제약
- `BattleSummaryCollector` 경로 결합 제거 전에 대체 데이터 소스(도메인 골드 소유자)를 먼저 준비해야 한다.
- `PlayGround` 네이밍 변경은 문자열 경로 의존 제거 또는 fallback 도입 이후에 진행해야 한다.
- 책임 분해(`PlayGround`)는 외부 공개 메서드 시그니처 호환을 유지하면서 내부부터 분리해야 회귀 리스크가 낮다.

## 4) 단계별 작업
### Phase 0. 기준선 고정 및 회귀 가드
- [x] 리서치 근거 확정 (`docs/tasks/playground-role-2026-02-28/research.md`)
- [ ] 현재 동작 기준선 기록
- [ ] 회귀 체크 시나리오 체크리스트 생성

작업 상세:
- 기준선 시나리오를 문서화한다.
- 전투 진입 시 시작 골드 반영, 카드 구매/리롤, 전투 종료 후 `gold_end` 반영, 히어로 소환/이동/사거리 표시에 대한 현재 동작을 명시한다.
- 회귀 판정 기준을 "동작 불변"과 "구조 개선"으로 분리한다.

산출물:
- `docs/tasks/playground-role-2026-02-28/plan.md` 내 기준선 시나리오 표
- 실행 시 체크할 수동 회귀 목록

완료 기준:
- 리팩토링 전/후 비교 가능한 시나리오 8개 이상 정의

### Phase 1. 전투 경제 도메인(UI 분리 1차)
- [x] 전투 골드/리롤/구매 상태의 도메인 소유자 신설
- [x] `ShopPanel`에서 도메인 상태 소유 로직 제거
- [x] `HeroHUD` 또는 별도 오케스트레이터에서 의도 전달/상태 반영 연결

작업 상세:
- 신규 서비스(예: `scripts/playground/domain/BattleEconomy.gd`)를 추가해 골드, 리롤 횟수, 구매 가능 판정을 소유하게 한다.
- `ShopPanel.gd`는 버튼 입력과 렌더링만 담당하도록 축소한다.
- 구매/리롤 요청은 신호 또는 명시 메서드 호출로 도메인 서비스에 위임한다.
- 도메인 서비스가 성공/실패 결과를 이벤트로 방출하고 UI는 이를 구독해 표시를 갱신한다.

대상 파일:
- 신규: `scripts/playground/domain/BattleEconomy.gd` (또는 동등 경로)
- 수정: `scripts/playground/ui/ShopPanel.gd`
- 수정: `scripts/playground/ui/HeroHUD.gd`
- 필요 시: `scenes/playground/ui/hero_hud.tscn` (주입 경로/노드 연결)

완료 기준:
- `ShopPanel.gd`에서 `_current_gold`, `_free_reroll_remaining`, `_paid_reroll_count` 상태 소유 제거
- UI가 도메인 상태를 읽기/표시만 하고 규칙 계산을 수행하지 않음

### Phase 2. 전투 요약 수집 경로 결합 제거(UI 분리 2차)
- [x] `BattleSummaryCollector`의 UI 트리 경로 역참조 제거
- [x] 골드 수집 소스를 도메인 서비스/API로 전환
- [x] 요약 계약(`summary["gold_end"]`) 회귀 없이 유지

작업 상세:
- `collect_gold_end()`가 `PlayGround/HeroHUD/.../ShopColumn`를 직접 조회하지 않도록 교체한다.
- Phase 1 도메인 서비스에서 `get_gold()`를 제공하고, 수집기는 해당 서비스만 참조하도록 만든다.
- 수집 실패 시 fallback 정책(예: payload gold 유지)을 명확히 한다.

대상 파일:
- 수정: `scripts/flow/screens/BattleSummaryCollector.gd`
- 수정: `scripts/flow/screens/BattleScreenHost.gd` (초기 골드 주입 경로 재배치 필요 시)
- 수정 가능: `scripts/flow/RunStateManager.gd` (계약 보정 필요 시)

완료 기준:
- `BattleSummaryCollector.gd`에 `PlayGround/HeroHUD/...` 문자열 경로가 남아있지 않음
- 전투 종료 후 런 골드 반영이 기존과 동일하게 동작

### Phase 3. PlayGround 책임 분해(OOP/SRP 1차)
- [x] `PlayGround` 내부 책임을 "오케스트레이션" 중심으로 축소
- [x] 스폰 셀 탐색 책임을 별도 컴포넌트/서비스로 분리
- [ ] 사거리 오버레이 셀 계산 책임 분리 또는 인터페이스 명확화

작업 상세:
- 스폰 탐색 로직(`_find_spawn_cell`, 점유 검사)을 `HeroSpawnResolver` 성격의 분리 객체로 이관한다.
- `PlayGround`는 외부 API(`summon_hero`, `build_world_path_to_target`, `set_hero_attack_range_overlay`)를 유지하되 내부 구현 의존성을 낮춘다.
- 전역 hero 그룹 스캔의 범위를 전투 컨텍스트로 제한(가능하면 `hero_container` 기준)해 캡슐화와 예측 가능성을 높인다.

대상 파일:
- 수정: `scripts/playground/PlayGround.gd`
- 신규 후보: `scripts/playground/domain/HeroSpawnResolver.gd`
- 필요 시 수정: `scripts/heroes/Hero.gd` (인터페이스 계약 보정 최소 범위)

완료 기준:
- `PlayGround.gd`의 private 헬퍼가 도메인 분리 객체로 이관되고 공개 API 호환 유지
- 전역 그룹 스캔 의존이 최소화되거나 범위 제한 근거가 문서화됨

### Phase 4. 네이밍/참조 안정화(`PlayGround` 이행 준비)
- [x] 하드코딩 문자열 경로를 상수/경로 주입 방식으로 전환
- [x] `PlayGround` vs `playground` 표기 병존 리스크 축소
- [x] 선택적 리네이밍 단계(호환 fallback 포함) 설계

작업 상세:
- `BattleScreenHost`, `BattleSummaryCollector`에서 `get_node_or_null("PlayGround/...")` 직접 문자열 사용을 제거한다.
- 경로 상수 또는 exported NodePath로 치환해 씬 구조 변경 내성을 확보한다.
- 실제 네이밍 변경이 필요하면 `"Playground"` 우선 조회 + `"PlayGround"` fallback의 이행 구간을 둔다.

대상 파일:
- 수정: `scripts/flow/screens/BattleScreenHost.gd`
- 수정: `scripts/flow/screens/BattleSummaryCollector.gd`
- 수정 가능: `scenes/levels/level_base.tscn`, `scenes/playground/playground.tscn`

완료 기준:
- 코드상 `PlayGround/...` 하드코딩 경로가 제거되거나 호환 fallback 전략이 적용됨
- 네이밍 변경 여부와 무관하게 런타임 조회 실패가 발생하지 않음

### Phase 5. 검증 및 문서 동기화
- [x] Godot CLI 검증 실행
- [ ] 수동 회귀 시나리오 수행
- [x] 문서 동기화(`TODO.md`, `GAME_PLAN.md`, task 문서) 완료

작업 상세:
- Godot 개발 변경(.gd/.tscn)이므로 headless CLI 검증을 필수 수행한다.
- WSL 소켓 오류 발생 시 AGENTS 규칙에 따라 PowerShell fallback을 실행한다.
- 결과는 응답에 pass/fail, 사용 명령, 핵심 에러 라인으로 보고한다.
- 구현 완료 시 `TODO.md`와 `GAME_PLAN.md`를 같은 작업에서 동기화한다.

대상 파일:
- 수정: `TODO.md`
- 수정: `GAME_PLAN.md`
- 갱신: `docs/tasks/playground-role-2026-02-28/research.md` (필요 시 결과 반영)
- 갱신: `docs/tasks/playground-role-2026-02-28/plan.md` (체크박스 완료 처리)

완료 기준:
- CLI 검증 결과가 pass이거나, blocked 시 대체 회귀 점검 기록이 존재
- TODO/GAME_PLAN 동기화 누락 없음

## 5) 검증 체크리스트
- [ ] 전투 시작 골드가 UI와 도메인 상태 모두 일치한다.
- [ ] 카드 구매/리롤 후 골드 차감 및 버튼 상태가 정확히 반영된다.
- [x] 전투 종료 요약의 `gold_end`가 UI 경로가 아닌 도메인 경로로 수집된다.
- [ ] `all_rounds_cleared`, `core_destroyed`, `all_heroes_dead` 종료 흐름 회귀가 없다.
- [ ] 히어로 소환/이동/사거리 표시 동작이 리팩토링 전과 동일하다.
- [x] `PlayGround` 경로 문자열 변경 또는 씬 구조 조정 시 치명적 null 경로 에러가 발생하지 않는다.
- [x] `_process`/`_physics_process` 신규 상시 폴링 루프를 도입하지 않았다.
- [x] Godot CLI 검증 결과 보고 형식이 AGENTS 규칙을 충족한다.

## 6) 리스크/대응
- 리스크: UI 분리 과정에서 상점 기능이 일시적으로 동작하지 않을 수 있음.
- 대응: Phase 1 완료 전까지 기존 `ShopPanel` API 호환 래퍼(`set_gold/get_gold`)를 유지하고, 단계적으로 내부 구현만 교체.

- 리스크: 요약 수집 경로 변경 후 `gold_end` 누락 가능성.
- 대응: `summary["gold_end"]` 기본값/폴백 정책을 명시하고, 전투 종료 시 로그 및 회귀 시나리오로 검증.

- 리스크: `PlayGround` 리네이밍을 서둘러 적용하면 다수 참조가 동시에 깨질 수 있음.
- 대응: 경로 주입/상수화 -> fallback 도입 -> 최종 rename 순으로 3단계 이행.

- 리스크: 책임 분해 중 API 깨짐으로 `Hero`/`HeroHUD` 호출 실패.
- 대응: 공개 메서드 시그니처 유지(`summon_hero`, `build_world_path_to_target`, `set_hero_attack_range_overlay`)를 강제하고 내부 구현만 분리.

- 리스크: 리팩토링 범위 확장으로 일정 지연.
- 대응: Phase 단위 PR/커밋 경계로 분할하고, Phase 2 완료 시점에 중간 안정화 태그를 찍는다.

## 7) 가정 및 미해결 질문
- 가정: 단일 전투 인스턴스 컨텍스트가 유지된다.
- 가정: `HeroNavRegion`은 현재 런타임 로직에서 직접 참조되지 않는다.
- 미해결 질문: 네이밍 통일 목표를 `Playground`로 확정할지, `PlayGround` 유지 + 참조 안정화만 할지.
- 해결 방법: Phase 4 시작 전 팀 합의 1회(네이밍 정책 결정) 후 경로 전략 확정.

## 8) 완료 선언 조건
- Phase 1~5 체크박스가 모두 `[x]`로 갱신되어 있다.
- `ShopPanel`의 도메인 상태 소유 제거와 `BattleSummaryCollector`의 UI 경로 의존 제거가 코드 diff로 확인된다.
- `PlayGround` 관련 경로 결합 리스크에 대한 대응(상수화/주입/fallback 중 하나 이상)이 반영된다.
- Godot CLI 검증 결과 보고가 완료된다.
- `TODO.md`와 `GAME_PLAN.md` 동기화가 같은 작업에서 완료된다.
- 본 문서의 `실행 상태`를 `완료 (YYYY-MM-DD)`로 갱신한다.
