# 계획: 전투 종료 조건/리소스 해제 정합성 개선

날짜: 2026-02-28
연결 리서치: `docs/tasks/battle-scene-end-condition-resource-cleanup-2026-02-28/research.md`
계획 상태 (2026-02-28): 진행 중 (구현 반영 완료, 수동 시나리오 검증 대기)
완료 상태 (2026-02-28): 미완료

## 1) 목표
- 전투 종료 조건을 코드/문서 기준으로 일치시킨다.
- 전투 종료 직후 전투 소유 리소스(특히 적 노드)가 100% 해제되도록 보장한다.
- 다음 전투 시작 시 `alive_enemy_count` 초기 오염을 제거한다.
- 종료 플로우 변경 후 승리/패배 분기와 저장 상태 반영이 기존과 동일하게 유지되도록 회귀를 통과한다.

## 2) 범위
### In Scope
- `scripts/spawn/EnemySpawnController.gd`: 적 스폰 부모(소유권) 교정
- `scripts/playground/ui/HeroHUD.gd`: 적 등록 이벤트 수집 경로 보강
- `scripts/flow/screens/BattleScreenHost.gd`: 종료 시 방어적 정리 루틴 보강
- `scripts/round/RoundManager.gd`, `scripts/round/ui/RoundManagerUI.gd`, `scripts/round/ui/RoundFailActionsUI.gd`: `game_failed` 미사용 정리 또는 명시화
- `GAME_PLAN.md`, `TODO.md`: 구현 반영 및 작업 기록 동기화

### Out of Scope
- 적/히어로 전투 밸런스 수치 변경
- 전투 UI 레이아웃/아트 리소스 변경
- 월드맵/런 메타 구조 변경

## 3) 단계별 작업 (Phase)
### Phase 0. 설계 확정 (선행 게이트)
목표: 구현 전 의사결정 고정
- [x] 종료 신호 정책 확정: `game_failed`를 실제 사용으로 복원할지, 미사용 신호를 정리할지 결정
- [x] 적 소유권 정책 확정: 적 노드를 전투 인스턴스 하위로 귀속하는 기준 노드 확정
- [x] HUD 적 등록 정책 확정: `current_scene.child_entered_tree` 의존 제거 방식 확정
- [x] 영향 파일 최종 목록 확정 및 수정 순서 고정
산출물:
- [x] 본 `plan.md`의 미해결 질문 섹션 업데이트
완료 기준:
- [x] Phase 1 착수 시점에 기술 선택이 단일안으로 고정됨

### Phase 1. 소유권 교정 구현
목표: 전투 종료 시 적 노드가 전투 트리와 함께 해제되도록 구조 교정
- [x] `scripts/spawn/EnemySpawnController.gd`에서 적 `add_child` 대상을 전투 인스턴스 하위 노드로 변경
- [x] 필요 시 스폰 부모 경로 export 추가 (`@export_group`/`##` 문서 주석 포함, R2 준수)
- [x] `scenes/levels/level_base.tscn`에서 스폰 부모 경로 Inspector 값 설정
- [x] 적 스폰 후 기존 동작 유지 확인: 위치 설정, 코어 타겟 설정, `enemy_spawned` 시그널 방출
산출물:
- [x] 수정 파일: `scripts/spawn/EnemySpawnController.gd`, `scenes/levels/level_base.tscn`
완료 기준:
- [x] 전투 종료 시 남아 있는 적 노드가 자동 해제되는 구조가 코드상 보장됨

### Phase 2. 적 등록/종료 정리 보강
목표: 소유권 변경으로 생길 수 있는 UI/종료 경계 문제를 제거
- [x] `scripts/playground/ui/HeroHUD.gd`의 적 등록 훅을 전투 트리 구조 변화에도 동작하도록 보강
- [x] `scripts/flow/screens/BattleScreenHost.gd` `hide_screen()`에 방어적 정리(잔존 적 스캔/정리) 필요 여부 결정 및 반영
- [x] 정리 범위는 "현재 전투 소유 적"으로 한정되도록 식별 기준(ancestor/meta 등) 적용
- [ ] 다음 전투 진입 시 `RoundManager` 초기 `alive_enemy_count`가 0 기준으로 시작되는지 확인
산출물:
- [x] 수정 파일: `scripts/playground/ui/HeroHUD.gd`, `scripts/flow/screens/BattleScreenHost.gd` (필요 시)
완료 기준:
- [ ] 전투 중 적 선택 UI 동작 회귀 없음 (수동 플레이 검증 대기)
- [ ] 전투 종료 후 적 잔존 0 보장

### Phase 3. 종료 시그널/문서 정합성 반영
목표: 코드와 문서의 종료 경로 설명을 일치시킴
- [x] `game_failed` 미사용 결정 시 관련 연결 코드 정리 또는 주석/명시 처리
- [x] `GAME_PLAN.md` 종료 경로 문구를 실제 코드(`BattleSummaryCollector` 기반 전멸 판정)로 동기화
- [x] `TODO.md`에 작업/검증 항목 추가 및 완료 상태 반영 (R7 준수)
산출물:
- [x] 수정 파일: `GAME_PLAN.md`, `TODO.md`, 라운드 UI/매니저 스크립트
완료 기준:
- [x] 문서/코드 불일치 항목 0건

### Phase 4. 검증 및 마감
목표: 기능/회귀/도구 검증 완료 후 종료
- [ ] 시나리오 검증 1: 라운드 전부 클리어 시 승리 종료 + 보상 화면 진입
- [ ] 시나리오 검증 2: 코어 파괴 시 패배 종료
- [ ] 시나리오 검증 3: 히어로 전멸 시 패배 종료
- [ ] 각 시나리오 종료 직후 `enemy` 그룹 잔존 노드 0 확인
- [x] Godot CLI 검증 실행 (R5): `/mnt/c/Godot_v4.6.1/Godot_v4.6.1-stable_win64_console.exe --headless --path . --quit`
- [x] WSL 실패 시 PowerShell fallback 실행/기록 (N/A: WSL 기본 명령 pass)
- [ ] 최종 변경 요약과 회귀 체크 결과를 사용자 응답에 명시
산출물:
- [ ] 검증 로그 요약(응답 본문), 필요 시 `docs/tasks/.../result.md`
완료 기준:
- [ ] 검증 체크리스트 전 항목 통과
- [ ] 계획 상태를 `완료`로 갱신

## 4) 검증 체크리스트
- [ ] 종료 조건이 `all_rounds_cleared / core_destroyed / all_heroes_dead`로만 동작한다.
- [ ] 전투 종료 후 적 잔존 노드가 0이다.
- [ ] 다음 전투 시작 시 `alive_enemy_count` 초기치가 잔존 적 영향 없이 시작된다.
- [ ] 전투 중 적 클릭/선택 UI가 정상 동작한다.
- [ ] 승리 시 `battle_reward_screen` 흐름이 유지된다.
- [ ] 패배 시 `run_result_screen` 흐름이 유지된다.
- [x] `GAME_PLAN.md`와 구현이 일치한다.
- [x] Godot CLI 검증 결과가 pass이거나, blocked 사유가 정책 형식으로 보고된다.

## 5) 리스크/대응
- 리스크: 적 스폰 부모 변경 시 `HeroHUD` 적 등록이 누락되어 클릭 선택이 깨질 수 있음
- 대응: 소유권 변경 직후 `HeroHUD` 등록 경로를 이벤트 기반으로 보강하고 회귀 시나리오에 적 클릭 검증 포함

- 리스크: 종료 시 전역 적 정리 로직이 과도하면 향후 비전투 씬 적까지 삭제할 수 있음
- 대응: 정리 대상 식별 기준을 전투 소유 범위(ancestor/meta)로 제한

- 리스크: `game_failed` 처리 정리 중 라운드 UI 경로가 깨질 수 있음
- 대응: 미사용 제거 시 연결 지점을 일괄 검색(`rg`)해 같이 정리하고 UI 회귀 체크 수행

- 리스크: 문서만 먼저 갱신하면 구현과 다시 어긋날 수 있음
- 대응: 코드 변경 완료 후 같은 커밋 흐름에서 `GAME_PLAN.md`/`TODO.md` 동시 반영

## 6) 가정/미해결 질문
- [x] `game_failed`를 완전 제거해도 되는지 제품 의도 확인 필요
- [x] 적 소유권을 "레벨 루트 직속"으로 둘지, "전용 EnemyContainer"를 둘지 선택 필요
- [x] 종료 시 방어적 정리를 코드에 남길지(이중 안전장치) 여부 확정 필요
- 해결 방식:
- [x] `Phase 0`에서 단일안 확정 후 계획 문서에 결정 로그를 남긴다.
- 결정 로그 (2026-02-28):
- `game_failed` 경로는 실제 emit이 없어 제거하고, 종료 원인은 `all_rounds_cleared/core_destroyed/all_heroes_dead` 3개로 고정
- 적 소유권은 전투 레벨 루트(전투 인스턴스 하위)로 귀속
- `BattleScreenHost.hide_screen()`의 추가 전역 정리는 적용하지 않음(소유권 교정으로 해제 보장)

## 7) 완료 선언 조건
- [ ] Phase 0~4 체크 항목 전부 `[x]` 처리
- [ ] 산출물 파일 경로가 응답에 명시됨
- [ ] 검증 결과(pass/fail/blocked, 사용 명령, 핵심 에러 라인)가 보고됨
- [ ] `TODO.md`와 `GAME_PLAN.md` 동기화 완료
- [ ] 계획 상태 라인이 `계획 상태 (YYYY-MM-DD): 완료`로 갱신됨
