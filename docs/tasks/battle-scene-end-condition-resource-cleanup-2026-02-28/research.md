# 리서치: 전투씬 종료 조건 및 종료 후 리소스 해제

날짜: 2026-02-28
작업: 전투씬 진행 후 종료 조건과 종료 시 해제되어야 할 리소스 조사

## 목적
- 현재 코드 기준 전투씬 종료 트리거를 정확히 확정한다.
- 전투 종료 직후 반드시 해제되어야 하는 런타임 리소스와 현재 해제 상태를 식별한다.
- 코드/문서 간 불일치와 누수 가능성을 정리해 후속 조치 기준을 만든다.

## 범위
- In Scope: `BattleScreenHost`, `RoundManager`, `Core`, `GameFlowController`, `EnemySpawnController`, `BattleSummaryCollector`, 전투 레벨/플로우 씬 구조
- Out of Scope: 전투 밸런스 수치 조정, UI 디자인 변경, 신규 시스템 구현

## 조사 방법
- 시그널 흐름 추적: `RoundManager/Core/Hero -> BattleScreenHost -> GameFlowController`
- 씬 소유권 분석: 전투 엔티티가 어느 부모 아래에 생성/해제되는지 확인
- 상태 수명 분석: 전투 요약/런 상태가 언제 clear/반영되는지 확인
- 문서 일치성 검증: `GAME_PLAN.md` 명세와 실제 코드 구현 비교

## 사실 근거
1. 전투 종료의 단일 게이트는 `BattleScreenHost._emit_once()`다.
- `_battle_completed` 플래그로 중복 종료를 차단하고 `battle_finished`를 1회만 방출한다.
- 근거: `scripts/flow/screens/BattleScreenHost.gd:169`, `scripts/flow/screens/BattleScreenHost.gd:170`, `scripts/flow/screens/BattleScreenHost.gd:174`

2. 실제 동작하는 종료 조건은 승리 1개, 패배 2개다.
- 승리: `RoundManager.all_rounds_cleared` 수신 시 `victory=true`.
- 패배: 코어 `destroyed` 수신 시 `reason=core_destroyed`.
- 패배: 히어로 전멸 판정 시 `reason=all_heroes_dead`.
- 근거: `scripts/flow/screens/BattleScreenHost.gd:36`, `scripts/flow/screens/BattleScreenHost.gd:43`, `scripts/flow/screens/BattleScreenHost.gd:147`, `scripts/flow/screens/BattleScreenHost.gd:155`, `scripts/flow/screens/BattleScreenHost.gd:159`, `scripts/flow/screens/BattleSummaryCollector.gd:37`, `scripts/core/Core.gd:48`, `scripts/round/RoundManager.gd:156`

3. `game_failed` 경로는 현재 선언/연결만 있고 실제 emit 지점이 없다.
- `RoundManager`에 `signal game_failed` 선언은 있으나 emit 코드가 없다.
- `BattleScreenHost`와 `RoundManagerUI`는 `game_failed`를 연결하지만 트리거는 발생하지 않는다.
- 근거: `scripts/round/RoundManager.gd:5`, `scripts/flow/screens/BattleScreenHost.gd:40`, `scripts/round/ui/RoundManagerUI.gd:45`

4. 라운드 총량 기준으로 승리 라운드는 현재 구성상 30라운드다.
- `RoundManager`는 `_get_total_round_count()`를 `EnemySpawnController.get_configured_round_count()`에 위임한다.
- `get_configured_round_count()`는 `round_enemy_scenes`, `round_spawn_counts`, `round_enemy_health_multipliers` 길이의 최댓값을 사용한다.
- 현재 레벨 값은 각각 2, 10, 30이므로 총 라운드 수는 30이다.
- 근거: `scripts/round/RoundManager.gd:203`, `scripts/spawn/EnemySpawnController.gd:113`, `scenes/levels/level_base.tscn:41`, `scenes/levels/level_base.tscn:42`, `scenes/levels/level_base.tscn:43`

5. 전투 종료 시 현재 확실히 해제되는 대상은 "전투 인스턴스 서브트리"와 "요약 참조"다.
- `hide_screen()`에서 `_battle_instance.queue_free()` 수행.
- 이어서 `_battle_instance` 참조, 시작 시각, 수집기 참조를 초기화한다.
- `GameFlowController`는 전투 종료 시 즉시 `hide_screen()`을 호출하며, 실패/메뉴 복귀 경로에서도 동일하게 호출한다.
- 근거: `scripts/flow/screens/BattleScreenHost.gd:51`, `scripts/flow/screens/BattleScreenHost.gd:53`, `scripts/flow/screens/BattleScreenHost.gd:57`, `scripts/flow/GameFlowController.gd:260`, `scripts/flow/GameFlowController.gd:395`

6. 전투 인스턴스에 포함된 주요 자원은 해제된다.
- 레벨 트리 내부 노드(`CoreRoot`, `SpawnTimer`, `EnemySpawnController`, `RoundSystem`, `PlayGround`, `HeroHUD`)는 전투 인스턴스 자식이므로 함께 해제된다.
- 근거: `scenes/levels/level_base.tscn:13`, `scenes/levels/level_base.tscn:19`, `scenes/levels/level_base.tscn:35`, `scenes/levels/level_base.tscn:38`, `scenes/levels/level_base.tscn:48`, `scenes/levels/level_base.tscn:52`, `scenes/playground/playground.tscn:29`

7. 해제 누락 위험이 있는 핵심 자원은 "전투 중 생성된 적 노드"다.
- `EnemySpawnController`는 적을 `get_tree().current_scene.add_child(enemy)`로 생성한다.
- 현재 메인 씬은 `scenes/flow/game_flow.tscn`이므로 적 노드는 `GameFlow` 루트에 붙는다.
- 이 구조에서는 `BattleScreenHost`가 `_battle_instance`만 `queue_free()`해도 생존 적은 자동 해제되지 않는다.
- 근거: `scripts/spawn/EnemySpawnController.gd:79`, `project.godot:14`, `scenes/flow/game_flow.tscn:14`, `scenes/flow/game_flow.tscn:17`, `scripts/flow/screens/BattleScreenHost.gd:53`

8. 위 누락은 다음 전투 라운드 로직 오염 리스크를 만든다.
- 다음 전투 시작 시 `RoundManager._count_alive_enemies_once()`는 그룹 전체 `enemy`를 스캔한다.
- 이전 전투 생존 적이 남아 있으면 `alive_enemy_count` 초기치가 오염될 수 있다.
- 근거: `scripts/round/RoundManager.gd:55`, `scripts/round/RoundManager.gd:172`, `scenes/enemies/base/enemy_base.tscn:224`

9. 문서와 코드 간 불일치가 1건 확인된다.
- 문서에는 `PlayGround.all_heroes_dead` 신호 경유라고 기재되어 있으나, 실제 코드는 `BattleSummaryCollector.connect_hero_death_signals()` + `are_all_heroes_dead()`로 처리한다.
- `PlayGround`에는 `all_heroes_dead` 신호 정의가 없다.
- 충돌 해소 기준은 런타임 동작을 결정하는 코드 우선으로 판단했다.
- 근거: `GAME_PLAN.md:154`, `scripts/flow/screens/BattleScreenHost.gd:47`, `scripts/flow/screens/BattleSummaryCollector.gd:24`, `scripts/playground/PlayGround.gd:1`

## 리스크/가정
- 리스크: 전투 종료 후 생존 적 잔존으로 다음 전투 카운트 오염, 불필요한 노드 상주, 화면/입력 간섭 가능성
- 리스크: `game_failed` 신호 미사용 상태가 유지되면 UI/플로우 코드 가독성 저하 및 오해 유발
- 리스크: 문서-코드 불일치가 유지되면 유지보수 시 잘못된 종료 경로를 전제로 수정할 가능성
- 가정: `GameFlow`가 런타임 동안 `current_scene`으로 유지된다는 전제에서 적 생성/잔존 리스크를 계산했다.
- 가정: 본 조사 범위 밖에서 적 전역 정리를 수행하는 숨은 코드가 없다고 가정했다.

## 결론
- 종료 조건 확정:
- `all_rounds_cleared`면 승리 종료
- `core_destroyed` 또는 `all_heroes_dead`면 패배 종료
- 종료 시 필수 해제 대상(현재 상태):
- 전투 인스턴스 서브트리: 현재 해제됨
- 전투 요약/참조 데이터(`_collector`, `pending_battle_summary`): 현재 해제/초기화됨
- 전투 중 생성 적 노드(현재 `current_scene` 직속): 해제 누락 위험 존재
- 후속 점검 우선순위:
- 전투 종료 직후 `enemy` 그룹 잔존 수 0 보장 여부를 자동 체크
- 적 생성 부모를 전투 인스턴스로 귀속하거나, 종료 시 전역 정리 루틴을 명시화
- `GAME_PLAN.md`의 종료 경로 설명을 현재 코드 기준으로 동기화

## 출처
- `scripts/flow/screens/BattleScreenHost.gd`
- `scripts/round/RoundManager.gd`
- `scripts/core/Core.gd`
- `scripts/spawn/EnemySpawnController.gd`
- `scripts/flow/GameFlowController.gd`
- `scripts/flow/screens/BattleSummaryCollector.gd`
- `scripts/playground/PlayGround.gd`
- `scenes/levels/level_base.tscn`
- `scenes/flow/game_flow.tscn`
- `scenes/enemies/base/enemy_base.tscn`
- `project.godot`
- `GAME_PLAN.md`

## 구현 반영 업데이트 (2026-02-28)
- 본 문서는 구현 전 조사 기준이며, 아래 항목은 구현으로 상태가 변경되었다.
- `game_failed` 경로: `RoundManager`/관련 UI에서 제거되어 현재 종료 원인 집합은 `all_rounds_cleared`, `core_destroyed`, `all_heroes_dead`로 정리됨.
- 적 소유권: `EnemySpawnController` 스폰 부모가 `spawn_parent_path`(기본 `..`, 레벨 루트)로 전환되어 전투 인스턴스 해제 시 적 노드도 함께 해제됨.
- 적 등록 경로: `HeroHUD`는 `SceneTree.node_added` 기반 등록으로 변경되어 부모 구조 변경에 대한 결합도가 낮아짐.
