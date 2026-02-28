# 리서치: PlayGround의 역할

날짜: 2026-02-28
작업: 현재 코드 기준 `PlayGround` 노드/스크립트의 역할 정의와 책임 경계 조사

## 목적
- `PlayGround`가 전투 씬에서 정확히 무엇을 담당하는지 확정한다.
- `BattleMap`, `Hero`, `HeroHUD`, `BattleScreenHost`와의 경계면(API/데이터 흐름)을 정리한다.
- 문서(`GAME_PLAN`, TODO 기록)와 실제 코드 간 불일치 여부를 확인해 후속 설계 기준으로 사용한다.

## 범위
- In Scope: `scenes/playground/playground.tscn`, `scripts/playground/PlayGround.gd`, `scripts/heroes/Hero.gd`, `scripts/playground/ui/HeroHUD.gd`, `scripts/maps/BattleMap.gd`, `scripts/flow/screens/BattleScreenHost.gd`, `scripts/flow/screens/BattleSummaryCollector.gd`, `scenes/levels/level_base.tscn`, `GAME_PLAN.md`, `docs/todo/2026-02-4w/*`
- Out of Scope: 전투 밸런스 수치 조정, 신규 기능 구현, 리팩터링 적용

## 조사 방법
- 씬 구조 추적: `level_base -> PlayGround -> HeroHUD/HeroContainer` 계층 확인
- 호출 흐름 추적: 전투 시작/맵 교체/히어로 생성/이동 명령/전투 종료 수집 흐름 확인
- 책임 경계 분석: `PlayGround`가 직접 처리하는 로직과 `BattleMap`/`Hero`에 위임하는 로직 분리
- 문서 정합성 검증: `GAME_PLAN`/TODO 기술과 현재 코드 동작 대조

## 사실 근거
1. `PlayGround`는 전투 레벨의 독립 자식 씬이며, 히어로 컨테이너·이동 마커·전투 HUD를 포함하는 허브다.
- `level_base.tscn`에서 `PlayGround`가 레벨 루트의 직접 자식으로 인스턴스된다.
- `playground.tscn` 내부에 `HeroContainer`, `MoveCommandMarker`, `HeroHUD`가 구성되어 있다.
- 근거: `scenes/levels/level_base.tscn:52`, `scenes/playground/playground.tscn:9`, `scenes/playground/playground.tscn:19`, `scenes/playground/playground.tscn:22`, `scenes/playground/playground.tscn:29`

2. 현재 `PlayGround`의 핵심 책임은 "히어로 런타임 오케스트레이션 + BattleMap 어댑터"다.
- 히어로 소환(`summon_hero`), 소환 클래스 순서 적용(`hero_spawn_class_order`), 스폰 위치 결정(`_find_spawn_cell`)을 직접 담당한다.
- 타일/경로/좌표는 자체 계산하지 않고 `BattleMap` API(`world_to_cell`, `build_world_path`, `is_walkable_cell`, `set_range_overlay`)로 위임한다.
- 근거: `scripts/playground/PlayGround.gd:15`, `scripts/playground/PlayGround.gd:74`, `scripts/playground/PlayGround.gd:105`, `scripts/playground/PlayGround.gd:124`, `scripts/playground/PlayGround.gd:134`, `scripts/maps/BattleMap.gd:98`, `scripts/maps/BattleMap.gd:124`, `scripts/maps/BattleMap.gd:112`, `scripts/maps/BattleMap.gd:185`

3. `PlayGround`는 전투 중 맵 변형 교체 지점에서도 안정적인 재바인딩 지점을 제공한다.
- `BattleScreenHost`가 `BattleMapSlot`의 맵 인스턴스를 교체한 뒤 `PlayGround.set_battle_map()`을 호출한다.
- `set_battle_map()`은 기존 오버레이 정리 -> 내비게이션 재빌드 -> 활성 히어로 오버레이 재그리기를 수행한다.
- 근거: `scripts/flow/screens/BattleScreenHost.gd:113`, `scripts/flow/screens/BattleScreenHost.gd:121`, `scripts/flow/screens/BattleScreenHost.gd:125`, `scripts/playground/PlayGround.gd:30`, `scripts/playground/PlayGround.gd:36`, `scripts/playground/PlayGround.gd:38`

4. `Hero`와 `HeroHUD`는 `PlayGround`를 통해 맵/표시 기능을 사용한다.
- `Hero`는 `playground` 참조를 통해 경로 빌드, 좌표 변환, 타일 크기 조회, 사거리 오버레이 반영을 수행한다.
- `HeroHUD`는 우클릭 이동 성공 시 `PlayGround.show_move_command_marker()`를 호출하고, 입력 기준 월드 좌표도 부모(`PlayGround`)에서 얻는다.
- 근거: `scripts/playground/PlayGround.gd:114`, `scripts/heroes/Hero.gd:192`, `scripts/heroes/Hero.gd:514`, `scripts/heroes/Hero.gd:521`, `scripts/heroes/Hero.gd:646`, `scripts/playground/ui/HeroHUD.gd:23`, `scripts/playground/ui/HeroHUD.gd:167`, `scripts/playground/ui/HeroHUD.gd:172`, `scripts/playground/ui/HeroHUD.gd:217`

5. `PlayGround`는 "전투 종료 조건 판정 주체"가 아니다.
- `PlayGround.gd`에는 `all_heroes_dead` 시그널 정의가 없다.
- 실제 전투 종료는 `BattleScreenHost`가 `RoundManager`/`Core`/`BattleSummaryCollector(히어로 그룹 스캔)`를 통해 판정한다.
- 근거: `scripts/playground/PlayGround.gd:1`, `scripts/flow/screens/BattleScreenHost.gd:36`, `scripts/flow/screens/BattleScreenHost.gd:43`, `scripts/flow/screens/BattleScreenHost.gd:47`, `scripts/flow/screens/BattleScreenHost.gd:159`, `scripts/flow/screens/BattleSummaryCollector.gd:24`, `scripts/flow/screens/BattleSummaryCollector.gd:37`

6. 문서 정합성은 부분 일치/부분 불일치다.
- 일치: `PlayGround`가 타일 데이터를 직접 소유하지 않고 `BattleMap` API를 사용한다는 문서는 코드와 일치한다.
- 불일치: `PlayGround.all_heroes_dead` 경유 종료라는 문구는 현재 코드와 불일치한다.
- 근거: `GAME_PLAN.md:257`, `scripts/playground/PlayGround.gd:56`, `scripts/playground/PlayGround.gd:74`, `GAME_PLAN.md:154`, `scripts/flow/screens/BattleSummaryCollector.gd:24`

7. 역할 변화 이력상 `PlayGround`는 "영역/충돌 직접 소유자"에서 "허브/위임자"로 이동했다.
- 2026-02-23 TODO에는 PlayGround 내부 이동 제한/중앙 소환/드래그 충돌 처리 중심으로 기록되어 있다.
- 2026-02-27 TODO에는 타일/경로 책임을 `BattleMap`으로 이관하고 `PlayGround` 타일 레이어 직접 소유를 제거했다고 기록되어, 현재 코드 구조와 일치한다.
- 근거: `docs/todo/2026-02-4w/2026-02-23.md:4`, `docs/todo/2026-02-4w/2026-02-23.md:5`, `docs/todo/2026-02-4w/2026-02-23.md:8`, `docs/todo/2026-02-4w/2026-02-27.md:28`, `docs/todo/2026-02-4w/2026-02-27.md:29`, `scripts/playground/PlayGround.gd:74`

8. 경계면상 주의할 엣지 케이스 2개가 확인된다.
- 스폰 점유 검사(`_is_cell_occupied_by_hero`)가 `get_tree().get_nodes_in_group("hero")` 전역 스캔 기반이라, 동일 트리 내 다른 컨텍스트 히어로가 남아 있으면 스폰 판단에 영향을 줄 수 있다.
- `BattleSummaryCollector.collect_gold_end()`가 `PlayGround/HeroHUD/.../ShopColumn` 고정 경로를 사용하므로 HUD 경로 변경 시 요약 수집이 깨질 수 있다.
- 근거: `scripts/playground/PlayGround.gd:168`, `scripts/playground/PlayGround.gd:175`, `scripts/flow/screens/BattleSummaryCollector.gd:106`

### 추가 조사 (2026-02-28, 네이밍/기능-UI 분리)

9. 네이밍은 "리소스 경로(`playground`)와 런타임 식별자(`PlayGround`)가 병존"하는 구조다.
- 씬/폴더 경로는 `scenes/playground/playground.tscn` 형태의 소문자 리소스 네이밍을 사용한다.
- 런타임 노드명/스크립트명/문자열 경로는 `PlayGround`를 사용한다.
- 근거: `scenes/levels/level_base.tscn:8`, `scenes/playground/playground.tscn:3`, `scenes/playground/playground.tscn:9`, `scenes/levels/level_base.tscn:53`, `scripts/flow/screens/BattleScreenHost.gd:63`, `scripts/flow/screens/BattleSummaryCollector.gd:106`

10. `PlayGround` 명칭은 현재 런타임 참조 키로 고정되어 있어, 단순 문자열 교체로 끝나지 않는다.
- `BattleScreenHost`, `BattleSummaryCollector`가 `get_node_or_null("PlayGround/...")` 형태 하드코딩 경로에 의존한다.
- 코드 기준 영향 범위는 최소 3개 스크립트(`BattleScreenHost`, `BattleSummaryCollector`, `PlayGround`) + 2개 씬(`level_base`, `playground`)이다.
- 근거: `scripts/flow/screens/BattleScreenHost.gd:63`, `scripts/flow/screens/BattleScreenHost.gd:78`, `scripts/flow/screens/BattleScreenHost.gd:123`, `scripts/flow/screens/BattleSummaryCollector.gd:106`, `scenes/levels/level_base.tscn:53`, `scenes/playground/playground.tscn:9`

11. 기능/UI 분리는 "히어로 상태 표시/입력 처리" 영역에서 대체로 유지된다.
- `HeroHUD`는 선택/입력 오케스트레이션을 맡고, 패널 데이터 바인딩(`bind_hero`)을 UI 자식 패널에 위임한다.
- `HeroInfoPanel`은 히어로 시그널을 구독해 라벨/체력바/초상화를 갱신하는 표시 책임에 집중한다.
- 근거: `scripts/playground/ui/HeroHUD.gd:3`, `scripts/playground/ui/HeroHUD.gd:251`, `scripts/playground/ui/HeroHUD.gd:252`, `scripts/playground/ui/HeroInfoPanel.gd:3`, `scripts/playground/ui/HeroInfoPanel.gd:102`, `scripts/playground/ui/HeroInfoPanel.gd:147`, `scripts/playground/ui/HeroInfoPanel.gd:230`

12. 기능/UI 분리는 "전투 골드/상점 규칙"에서 깨지는 지점이 있다.
- `ShopPanel` UI 스크립트가 `_current_gold`, 리롤 비용, 구매 비용, 장착 호출(`hero.equip_item`)까지 소유해 도메인 상태/규칙을 함께 담당한다.
- 전투 진입 시 골드 주입은 `BattleScreenHost -> HeroHUD.set_starting_gold -> ShopPanel.set_gold` 흐름으로 UI 레이어에 직접 주입된다.
- 근거: `scripts/playground/ui/ShopPanel.gd:35`, `scripts/playground/ui/ShopPanel.gd:64`, `scripts/playground/ui/ShopPanel.gd:157`, `scripts/playground/ui/ShopPanel.gd:161`, `scripts/playground/ui/ShopPanel.gd:170`, `scripts/flow/screens/BattleScreenHost.gd:60`, `scripts/flow/screens/BattleScreenHost.gd:78`, `scripts/flow/screens/BattleScreenHost.gd:80`, `scripts/playground/ui/HeroHUD.gd:66`

13. 플로우/저장 계층이 UI 트리 경로를 역참조해 전투 결과를 수집하는 결합이 존재한다.
- `BattleSummaryCollector.collect_gold_end()`는 `PlayGround/HeroHUD/.../ShopColumn` 경로에서 골드를 읽는다.
- 이 값이 `summary["gold_end"]`로 반영되고, `RunStateManager.apply_battle_summary()`가 런 상태 골드를 갱신한다.
- 즉, 도메인 상태(런 골드) 저장이 UI 노드 경로 안정성에 간접 의존한다.
- 근거: `scripts/flow/screens/BattleSummaryCollector.gd:76`, `scripts/flow/screens/BattleSummaryCollector.gd:103`, `scripts/flow/screens/BattleSummaryCollector.gd:106`, `scripts/flow/screens/BattleSummaryCollector.gd:111`, `scripts/flow/RunStateManager.gd:168`, `scripts/flow/RunStateManager.gd:169`, `scripts/flow/RunStateManager.gd:172`

14. `PlayGround` 자체도 도메인 오케스트레이션과 월드 표현 제어를 함께 가진 혼합 책임 상태다.
- 도메인 측: 히어로 소환/스폰 셀 계산/경로 위임.
- 표현 측: 이동 마커 표시 호출, 사거리 오버레이용 fill/border 셀 생성 후 렌더 계층(`BattleMap`)에 전달.
- 근거: `scripts/playground/PlayGround.gd:80`, `scripts/playground/PlayGround.gd:89`, `scripts/playground/PlayGround.gd:105`, `scripts/playground/PlayGround.gd:134`, `scripts/playground/PlayGround.gd:196`, `scripts/playground/PlayGround.gd:207`

## 리스크/가정
- 리스크: `GAME_PLAN`의 `PlayGround.all_heroes_dead` 기술이 유지되면 종료 조건 수정 시 잘못된 진입점을 건드릴 가능성이 있다.
- 리스크: 전역 hero 그룹 스캔(스폰 점유 검사, 요약 수집)이 다중 전투 인스턴스/잔존 노드 상황에서 사이드이펙트를 만들 수 있다.
- 리스크: `collect_gold_end`의 깊은 노드 경로 의존이 UI 구조 변경에 취약하다.
- 리스크: `PlayGround` 네이밍을 `Playground` 계열로 교정하려면 런타임 문자열 경로 참조(`get_node_or_null("PlayGround/...")`)가 동시에 정리되지 않으면 즉시 런타임 깨짐이 발생한다.
- 리스크: 상점 골드/리롤 규칙이 UI 스크립트에 남아 있으면 UI 리팩터링이 곧 전투 밸런스/런 상태 회귀로 이어질 수 있다.
- 리스크: `PlayGround`의 표현 책임(마커/오버레이 셀 생성)이 계속 확장되면 도메인 허브와 뷰 어댑터 경계가 더 흐려질 수 있다.
- 가정: 일반 런타임에서 전투 인스턴스는 1개이며, hero 그룹 노드는 해당 전투 트리 안에만 존재한다고 가정했다.
- 가정: `HeroNavRegion`은 현재 코드에서 직접 참조되지 않으므로(검색 결과 없음) 구조상 유산 노드일 가능성이 있다고 판단했다.
- 가정: 리포지토리 외부(외부 툴/에디터 플러그인/별도 브랜치)에서 `PlayGround` 문자열을 직접 참조하는 추가 의존은 없다고 가정했다.

## 결론
- **확정(코드로 확인됨)**: `PlayGround`의 현재 역할은 `Hero`/`HeroHUD`/`BattleMap` 사이의 전투 현장 오케스트레이터다.  
  히어로 생성/스폰, 이동 마커 표시, 사거리 오버레이 요청, 맵 교체 재바인딩을 담당한다.
- **확정(비책임)**: 전투 종료 조건 판정(`all_heroes_dead` 포함)의 소유자는 `BattleScreenHost + BattleSummaryCollector`이며, `PlayGround`는 종료 신호 소유자가 아니다.
- **확정(네이밍 현황)**: 현재 프로젝트 런타임 기준 정식 식별자는 `PlayGround`이며, 실제 참조 경로가 하드코딩되어 있어 "동작상 올바른 이름"으로 고정되어 있다.
- **추론(네이밍 품질)**: 영어 단어/리소스 경로(`playground`)와의 표기 일관성까지 목표로 한다면 `Playground`로 수렴하는 편이 읽기/검색성 측면에서 유리하다.
- **확정(분리도 평가)**: 기능/UI 분리는 "히어로 상태 표시 계층"에서는 양호하지만, "전투 골드/상점 규칙"은 UI(`ShopPanel`)에 도메인 로직이 결합되어 완전 분리 상태는 아니다.
- **추론(우선순위)**: 실질 리스크는 네이밍 그 자체보다 `UI 경로 의존(summary gold 수집)`과 `UI 내부 도메인 상태 소유`에서 더 크다.
- **추론(설계 의도)**: 최근 구조는 `PlayGround`를 맵 세부 구현에서 분리해(`BattleMap` 위임) 전투 맵 변형 교체와 UI/히어로 연동을 안정화하려는 방향이다.
- **미확정(후속 확인 필요)**:
  - `HeroNavRegion` 노드를 유지할지 제거할지(현재 참조 부재)
  - 전역 hero 스캔이 장기적으로도 단일 전투 컨텍스트를 전제해도 되는지
  - `GAME_PLAN.md` 종료 조건 문구를 코드 기준으로 언제 동기화할지
  - `PlayGround -> Playground` 리네이밍 필요성이 팀 규칙(영문 표기 통일 우선순위)에서 실제로 높은지
  - 골드/상점 도메인을 UI 밖 서비스로 분리할 때 저장 포맷/전투 요약 계약을 어떻게 재정의할지

## 출처
- `scenes/levels/level_base.tscn`
- `scenes/playground/playground.tscn`
- `scenes/playground/ui/hero_hud.tscn`
- `scripts/playground/PlayGround.gd`
- `scripts/heroes/Hero.gd`
- `scripts/playground/ui/HeroHUD.gd`
- `scripts/playground/ui/HeroInfoPanel.gd`
- `scripts/playground/ui/ShopPanel.gd`
- `scripts/maps/BattleMap.gd`
- `scripts/flow/screens/BattleScreenHost.gd`
- `scripts/flow/screens/BattleSummaryCollector.gd`
- `scripts/flow/RunStateManager.gd`
- `GAME_PLAN.md`
- `docs/todo/2026-02-4w/2026-02-23.md`
- `docs/todo/2026-02-4w/2026-02-27.md`
