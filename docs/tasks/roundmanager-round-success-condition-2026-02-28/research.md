# 리서치: RoundManager 라운드 성공 종료 조건

날짜: 2026-02-28
작업: `RoundManager`에서 라운드가 "성공적으로 끝났다"고 판정되는 조건 조사

## 목적
- 현재 코드 기준으로 라운드 성공 종료 조건을 정확히 정의한다.
- "웨이브 전환(다음 라운드 이동)"과 "전체 라운드 클리어(전투 승리)"를 분리해 조건을 명확히 한다.
- 조건이 성립하는 최소 신호/상태 경로를 파일 단위로 고정한다.

## 범위
- In Scope:
- `scripts/round/RoundManager.gd`
- `scripts/spawn/EnemySpawnController.gd`
- `scripts/round/ui/RoundTopCenterUI.gd`
- `scripts/flow/screens/BattleScreenHost.gd`
- `scripts/flow/screens/BattleSummaryCollector.gd`
- `scripts/core/Core.gd`
- `scripts/debug/DebugRoundControls.gd`
- `scenes/levels/level_base.tscn`
- Out of Scope:
- 밸런스 수치 조정(체력/스폰 간격 튜닝)
- UI 스타일/레이아웃 개선
- 신규 실패 조건 추가 설계

## 조사 방법
- 라운드 진입/종료 핵심 함수 추적: `begin_wave()`, `_can_advance_next_round_early()`, `_advance_to_next_round()`.
- 스폰 완료 판정 추적: `EnemySpawnController.is_round_spawn_finished()`.
- 전투 승리 소비자 추적: `BattleScreenHost`의 `all_rounds_cleared` 수신 후 `battle_finished(victory=true)` 흐름 확인.
- 엣지 케이스 확인:
- 타이머 만료 시 생존 적이 있어도 라운드가 넘어가는지
- 최종 라운드 판정 기준(총 라운드 수 계산식)
- 실패 시그널과 승리 시그널의 선후 경쟁(emit 순서)

## 사실 근거
1. 웨이브 진행 중(`WAVE_ACTIVE`)에는 남은 시간이 0이 되면 즉시 다음 라운드 전이 함수가 호출된다.
- `RoundManager._process()`는 `remaining_round_seconds <= 0.0`일 때 `_advance_to_next_round()`를 호출한다.
- 이 분기에는 `alive_enemy_count == 0` 조건이 없다.
- 근거: `scripts/round/RoundManager.gd:62`, `scripts/round/RoundManager.gd:77`

2. "조기 다음 라운드 가능"은 3조건이 모두 참일 때만 열린다.
- 시간 남음: `remaining_round_seconds > 0`
- 생존 적 없음: `alive_enemy_count <= 0`
- 해당 라운드 스폰 완료: `EnemySpawnController.is_round_spawn_finished() == true`
- 근거: `scripts/round/RoundManager.gd:182`, `scripts/round/RoundManager.gd:185`, `scripts/round/RoundManager.gd:187`, `scripts/spawn/EnemySpawnController.gd:116`

3. 조기 진행 가능 상태가 되어도 자동 전이는 아니다.
- `_check_advance_conditions()`는 `is_next_round_available` 플래그와 시그널만 갱신한다.
- 실제 전이는 `request_next_round()` 호출이 필요하며, 이 호출은 UI의 "다음 라운드 시작" 버튼에서 발생한다.
- 근거: `scripts/round/RoundManager.gd:142`, `scripts/round/RoundManager.gd:111`, `scripts/round/ui/RoundTopCenterUI.gd:85`

4. "전체 라운드 성공 클리어"의 직접 조건은 `_advance_to_next_round()` 진입 시 현재 라운드가 최종 라운드인 경우다.
- `_is_final_round()`가 참이면 `state = CLEARED` 후 `all_rounds_cleared.emit()`를 발생시킨다.
- 즉, 성공 종료 이벤트의 1차 트리거는 "최종 라운드에서 전이 시도 발생"이다.
- 근거: `scripts/round/RoundManager.gd:150`, `scripts/round/RoundManager.gd:151`, `scripts/round/RoundManager.gd:155`, `scripts/round/RoundManager.gd:194`

5. 최종 라운드 수는 스폰 컨트롤러 설정 테이블 길이의 최댓값이다.
- `RoundManager`는 총 라운드 수를 `EnemySpawnController.get_configured_round_count()`에 위임한다.
- `get_configured_round_count()`는 `round_enemy_scenes`, `round_spawn_counts`, `round_enemy_health_multipliers` 길이의 최대값을 반환한다.
- 현재 `level_base.tscn` 값은 각각 2/10/30이므로 총 라운드 수는 30이다.
- 근거: `scripts/round/RoundManager.gd:202`, `scripts/spawn/EnemySpawnController.gd:124`, `scenes/levels/level_base.tscn:41`, `scenes/levels/level_base.tscn:42`, `scenes/levels/level_base.tscn:43`

6. 생존 적 카운트는 스폰/사망/트리 이탈 이벤트로 유지되며, 조기 진행 조건의 핵심 입력값이다.
- 스폰 시 `alive_enemy_count += 1`
- 사망 시 `alive_enemy_count -= 1`
- 트리 이탈 시(사망이 아닌 경우) `alive_enemy_count -= 1`
- 초기값은 `enemy` 그룹 스캔에서 살아있는 개체 수로 1회 계산한다.
- 근거: `scripts/round/RoundManager.gd:119`, `scripts/round/RoundManager.gd:128`, `scripts/round/RoundManager.gd:133`, `scripts/round/RoundManager.gd:171`, `scenes/enemies/base/enemy_base.tscn:197`, `scripts/enemies/Enemy.gd:165`, `scripts/enemies/Enemy.gd:576`

7. 실제 전투 승리 확정은 `RoundManager` 단독이 아니라 `BattleScreenHost`에서 소비된다.
- `BattleScreenHost`는 `RoundManager.all_rounds_cleared`를 수신해 `battle_finished(victory=true)`를 1회 emit한다.
- 동시에 코어 파괴/전체 영웅 사망도 패배 종료를 emit하며, `_emit_once()`로 "먼저 도착한 종료 원인"만 채택된다.
- 근거: `scripts/flow/screens/BattleScreenHost.gd:40`, `scripts/flow/screens/BattleScreenHost.gd:166`, `scripts/flow/screens/BattleScreenHost.gd:170`, `scripts/flow/screens/BattleScreenHost.gd:174`, `scripts/flow/screens/BattleScreenHost.gd:184`, `scripts/core/Core.gd:48`, `scripts/flow/screens/BattleSummaryCollector.gd:39`

8. 디버그 강제 진행은 정상 조기 조건을 우회하지만, 최종 라운드 클리어를 직접 발생시키지는 않는다.
- `DebugRoundControls`는 최종 라운드(`current_round >= total_round_count`)에서는 동작하지 않고 즉시 반환한다.
- 따라서 디버그 버튼으로 "마지막 라운드 클리어 emit"을 직접 우회 발생시키는 경로는 없다.
- 근거: `scripts/debug/DebugRoundControls.gd:35`, `scripts/debug/DebugRoundControls.gd:40`

## 리스크/가정
- Known(코드로 확인):
- 최종 성공 시그널은 `all_rounds_cleared` 단일 경로다.
- 타이머 만료 전이 경로에는 "생존 적 0" 검사가 없다.
- Inferred(코드 흐름 기반 추론):
- 현재 설계는 "라운드 시간 기반 진행 + 선택적 조기 진행" 모델이며, "적 전멸 강제형 라운드"는 아니다.
- Uncertain(추가 검증 필요):
- 실제 플레이에서 최종 라운드 종료 프레임에 `core_destroyed`와 `all_rounds_cleared`가 경합할 때, 의도한 승패 우선순위가 맞는지(현재는 먼저 emit된 이벤트 우선).
- 레벨별 커스텀 씬(`level_base` 외)에서 총 라운드 수가 다른 경우 UX 텍스트/보상 설계가 일치하는지.

## 결론
- `RoundManager` 기준 "라운드 성공 종료(전이)"는 아래 두 경로 중 하나다.
- 경로 A(자동): 웨이브 타이머 0초 도달 -> `_advance_to_next_round()`
- 경로 B(수동 조기): 시간 남음 + 생존 적 0 + 스폰 완료 -> `request_next_round()` -> `_advance_to_next_round()`
- "전투 최종 승리"는 위 전이 함수가 **최종 라운드에서 호출**될 때 발생하며, `all_rounds_cleared` emit 후 `BattleScreenHost`가 `battle_finished(victory=true)`로 확정한다.
- 현재 `level_base` 기준 최종 라운드는 30라운드다.

## 출처
- `scripts/round/RoundManager.gd`
- `scripts/spawn/EnemySpawnController.gd`
- `scripts/round/ui/RoundTopCenterUI.gd`
- `scripts/flow/screens/BattleScreenHost.gd`
- `scripts/flow/screens/BattleSummaryCollector.gd`
- `scripts/core/Core.gd`
- `scripts/debug/DebugRoundControls.gd`
- `scripts/enemies/Enemy.gd`
- `scenes/enemies/base/enemy_base.tscn`
- `scenes/levels/level_base.tscn`

---

## 업데이트 (2026-02-28): 스폰 전략(랜덤 vs 순서형) 심화 조사

### 목적
- `enemies` 기반 JSON 구조로 전환할 때, 스폰 전략을 랜덤형으로 갈지 순서형으로 갈지 기술적으로 비교한다.
- 구현 전 의사결정에 필요한 리스크/확장성/디버깅 난이도를 고정한다.

### 범위
- In Scope:
- `scripts/spawn/EnemySpawnController.gd`
- `scripts/round/RoundManager.gd`
- `scripts/flow/GameFlowController.gd`
- `scripts/flow/screens/BattleScreenHost.gd`
- `scripts/flow/WorldMapGenerator.gd`
- `scripts/items/ItemDatabase.gd`
- `scenes/round/round_system.tscn`
- `scenes/levels/level_base.tscn`
- `scenes/enemies/variants/enemy_orc.tscn`
- `scenes/enemies/variants/enemy_orc2.tscn`
- Out of Scope:
- 실제 JSON 스키마 적용 코드 작성
- 실제 전투 밸런스 수치 확정

### 조사 방법
- 현재 스폰 루프/라운드 전이 조건/타이머 제약을 코드로 역추적했다.
- 프로젝트 내 기존 weighted random 구현 패턴(월드맵/아이템)을 재사용 가능성 관점에서 비교했다.
- 제거 예정 정책(`health_multiplier`, `rounds`) 반영 시 난이도 곡선 유지 가능성을 검토했다.

### 사실 근거
1. 현재 스폰은 단일 타이머 timeout 이벤트에서만 발생하며, 즉시 스폰은 없다.
- `begin_round_spawn()`는 타이머 `start()`만 호출한다.
- 실제 스폰은 `_on_spawn_timer_timeout()`에서만 수행된다.
- 근거: `scripts/spawn/EnemySpawnController.gd:104`, `scripts/spawn/EnemySpawnController.gd:67`, `scripts/spawn/EnemySpawnController.gd:70`

2. 라운드 만료 시 스폰이 남아 있어도 다음 라운드로 넘어간다.
- `RoundManager._process()`가 남은 시간 0초 이하에서 `_advance_to_next_round()`를 강제 호출한다.
- 근거: `scripts/round/RoundManager.gd:77`, `scripts/round/RoundManager.gd:150`

3. 현재 씬 값 기준 라운드당 실질 스폰 상한은 타이머와 라운드 시간에 의해 제한된다.
- `round_duration_seconds=40.0`, `SpawnTimer.wait_time=1.5`.
- 즉시 스폰이 없으므로 timeout 횟수 기준 이론상 최대 약 `floor(40.0 / 1.5) = 26`.
- 근거: `scenes/round/round_system.tscn:15`, `scenes/levels/level_base.tscn:36`, `scripts/spawn/EnemySpawnController.gd:70`
- 추론: 배열의 높은 스폰 수를 넣어도 물리적으로 모두 소화되지 않을 수 있음.

4. 현재 적 변형 2종은 전투 스탯 차이가 사실상 없고(거의 비주얼 차이), 체력 배율 제거 시 난이도 차별화 수단이 급감한다.
- `enemy_orc`, `enemy_orc2` 모두 `enemy_base` 인스턴스 기반.
- `enemy_orc2`는 주로 스프라이트 프레임 교체가 중심.
- 근거: `scenes/enemies/variants/enemy_orc.tscn:5`, `scenes/enemies/variants/enemy_orc2.tscn:135`, `scenes/enemies/base/enemy_base.tscn:201`
- 추론: `health_multiplier` 제거 후에는 "적 타입 자체 스탯 차이" 또는 "스폰 연출 제어"가 난이도 핵심이 됨.

5. 프로젝트에는 이미 weighted random 패턴이 2곳 이상 존재해 재사용 설계가 가능하다.
- 월드맵 타입 weighted pick 유틸 존재.
- 아이템 드로우 weighted pick 유틸 존재.
- 근거: `scripts/flow/WorldMapGenerator.gd:209`, `scripts/items/ItemDatabase.gd:81`

6. 전투 진입 payload에는 run seed/node_id가 전달되어 deterministic random 설계가 가능하다.
- `GameFlowController`가 `seed`, `node_id`를 전투 payload로 전달.
- `BattleScreenHost`는 동일 seed를 맵 변형 선택에 이미 사용한다.
- 근거: `scripts/flow/GameFlowController.gd:252`, `scripts/flow/GameFlowController.gd:253`, `scripts/flow/screens/BattleScreenHost.gd:140`

### 대안 분석
1. 옵션 A: `enemies` 목록 기반 랜덤 스폰
- 구조 예: `enemies[] = {scene_path, spawn_count, weight(optional)}`
- 장점:
- 데이터 구조가 단순하고, 적 추가/삭제가 빠르다.
- 레벨별 실험(체감 난이도) 반복 속도가 빠르다.
- 기존 weighted random 패턴 재사용이 쉽다.
- 단점:
- 라운드별 연출(초반 약/후반 강) 보장이 어렵다.
- 디버깅 시 "왜 이 라운드가 어려웠나" 재현성이 떨어질 수 있다(시드 고정 없으면 더 심함).
- `health_multiplier` 제거 후 난이도 튜닝이 랜덤 분산에 민감해진다.

2. 옵션 B: 순서 기반 스폰 플랜
- 구조 예: `spawn_plan[]`(라운드/구간별 등장 목록), `enemies[]`는 카탈로그
- 장점:
- 라운드별 체험(도입-상승-피크)을 직접 설계할 수 있다.
- QA 재현성과 버그 분석이 쉬워진다.
- `health_multiplier` 제거 이후에도 난이도 곡선을 안정적으로 설계 가능하다.
- 단점:
- 데이터 양과 유지비가 증가한다.
- 레벨별 파일에서 수정 포인트가 많아져 초기 작성 비용이 커진다.

3. 옵션 C: 하이브리드(권장)
- `enemies[]`는 필수 카탈로그로 유지
- `spawn_plan[]`은 선택(있으면 순서형, 없으면 랜덤형 fallback)
- 장점:
- 초기에는 랜덤으로 빠르게 개발하고, 필요한 레벨만 순서형으로 고정 가능
- 장기적으로 콘텐츠 규모가 커져도 유연성 유지
- 단점:
- 모드가 2개라 초기 구현/검증 범위가 다소 넓어진다.

### 권장 방안
- 권장: **옵션 C(하이브리드)** 채택
- 1차(빠른 고정): `enemies[]` + 랜덤(시드 고정) 모드
- 2차(난이도 정밀화): `spawn_plan[]` 추가로 특정 레벨/라운드만 순서형 지정
- 근거:
- 현재 요구는 `enemies` 구조 확정 + 레벨별 분리이며, 동시에 "라운드별 직접 제어" 니즈가 존재한다.
- 단일 랜덤만으로는 후반 난이도/연출 통제가 약하고, 단일 순서형만으로는 운영 속도가 느리다.

### 권장 데이터 계약 (초안)
- 공통:
- `version: int`
- `enemies: Array[{ id: String, scene_path: String, spawn_count: int, weight: float(optional) }]`
- 선택:
- `spawn_plan: Array[{ round: int, enemy_id: String, count: int }]`
- 모드 규칙:
- `spawn_plan`이 있으면 순서형 우선 적용
- 없으면 `enemies` 기반 랜덤 적용
- fail-fast:
- `scene_path` 로드 실패
- `spawn_count <= 0`
- `spawn_plan.enemy_id`가 `enemies.id`에 없음
- `spawn_plan.round`가 `final_round` 범위를 벗어남

### 추가 확정 (2026-02-28)
- `spawn_count` 의미: 라운드당 수량
- `spawn_plan`이 없을 때 동작: `enemies[].weight` 가중치 랜덤 fallback

### 리스크/가정
- Known:
- `health_multiplier` 제거 시 적 타입/스폰 제어가 난이도 핵심이 된다.
- `final_round`와 스폰 데이터가 분리되어 있어, 밸런스 품질은 스폰 정책에 크게 의존한다.
- Inferred:
- 랜덤 모드 단독 운용은 레벨별 난이도 곡선 품질 편차를 키울 가능성이 높다.
- Uncertain:
- 현재 콘텐츠(적 2종)만으로도 충분한 체감 차이를 만들 수 있는지.

### 결론
- 구현 전 의사결정 1건은 "스폰 전략"이며, 기술적으로는 하이브리드가 가장 안전하다.
- 즉시 구현 최소안은 랜덤(시드 고정)이나, 사용자 요구(라운드별 직접 제어)를 충족하려면 `spawn_plan` 같은 순서형 레이어가 필요하다.
- 따라서 **`enemies`는 유지하되, `spawn_plan` 옵션을 포함한 2단계 방안**이 현재 요구와 확장성 모두를 만족한다.

### 추가 출처
- `scripts/spawn/EnemySpawnController.gd`
- `scripts/round/RoundManager.gd`
- `scripts/flow/GameFlowController.gd`
- `scripts/flow/screens/BattleScreenHost.gd`
- `scripts/flow/WorldMapGenerator.gd`
- `scripts/items/ItemDatabase.gd`
- `scenes/round/round_system.tscn`
- `scenes/levels/level_base.tscn`
- `scenes/enemies/variants/enemy_orc.tscn`
- `scenes/enemies/variants/enemy_orc2.tscn`
