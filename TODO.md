# TODO

## 이번 주 (2026-02-4w)
- [x] Hero 자동공격 v1 구현
	- [x] HeroBase에 `AttackRange(Area2D)` + `AttackTimer(Timer)` 추가 (Inspector-authoritative)
	- [x] Hero 자동공격 로직 추가: 이벤트 기반 타겟 캐시 + 쿨다운 즉시타격
	- [x] 타겟 규칙 확정: 경로 진척도 최우선, 동률 시 거리 우선
	- [x] 공격 방향 기준 좌/우 반전 적용 (기본 우측, 좌측 타겟 시 `flip_h=true`)
	- [x] Hero 드래그/클릭 시 공격 범위 프리뷰 표시
	- [x] 드래그 충돌체 프리뷰 기본 비활성화 + Inspector 디버그 토글(`show_drag_collision_debug`)
	- [x] Hero 애니메이션 단순화: `idle`, `attack01`만 유지 (기타 상태/재생 제거)
		- [x] Hero 공격속도 표기 변경: `Attack Interval(초)` -> `attacks_per_second(초당 공격 횟수)`
		- [x] Hero 액션 애니메이션 재시작 기본화: `play_*` 호출은 동일 상태여도 강제 재시작
		- [x] Hero 동일상태 force 재시작 보장: `AnimatedSprite2D` same-animation 케이스 `stop()+play()` 적용
		- [x] Hero APS-모션 동기화: `attacks_per_second`에 맞춰 `attack01` 재생속도(`speed_scale`) 자동 결정 (min/max clamp 제거)
		- [x] Hero 타격 프레임 지정: `attack_hit_frame_index`(0-based)로 `attack01` 내 실제 타격 시점 제어
		- [x] Hero 타겟 우선순위 export 선택 추가: 경로 진척도 / 체력 낮은 순 / 가장 가까운 순
		- [x] 성능/아키텍처 리뷰: 타겟 목록은 `area_entered/area_exited` 신호 기반, 프레임 루프 내 `get_nodes_in_group` 미사용
	- [x] 회귀 체크포인트: 드래그 중 공격 중지 옵션, Enemy `apply_damage`/HealthBar 신호 경로 유지, Round alive 카운트 로직 비침범
	- [x] Godot CLI 검증: PASS (`/mnt/c/Godot_v4.6.1/Godot_v4.6.1-stable_win64_console.exe --headless --path . --quit`)
- [ ] Enemy non-loop 종료 규칙 회귀 확인 (실행 중 확인 필요)
	- [x] 피격(`HURT`) 종료 후 `IDLE` 고정 회귀 수정: `WALK` 복귀로 변경
	- [x] 사망(`DEATH`) 종료 후 잔존 회귀 수정: `auto_free_on_death_end=true` 기본값 반영
	- [x] 변형 씬 override 회귀 수정: `enemy_orc.tscn`의 `auto_free_on_death_end=false` 제거 (base 상속)
	- [x] 사망 즉시 PathFollow 분리: `PathFollow2D`에서 해제 후 현재 위치 고정 (에이전트 정리 포함)
	- [x] 사망 후 3초 알파 페이드아웃 적용: death 시점부터 `modulate.a -> 0` tween 후 free
	- [x] Enemy 애니메이션 단순화: `walk`, `hurt`, `death`만 유지 (idle/attack 제거)
	- [x] Enemy 액션 애니메이션 재시작 기본화: `play_walk/hurt/death` 동일 상태 재호출 시 재시작
	- [x] Enemy 동일상태 force 재시작 보장: `AnimatedSprite2D` same-animation 케이스 `stop()+play()` 적용
	- [x] Enemy HP 0 즉시 체력바 숨김 제거: Enemy free 시점까지 표시 유지
	- [x] Enemy 피격 데미지 숫자 표시 추가: 흰색 텍스트 + 검정 아웃라인, 페이드 업 애니메이션
	- [x] 성능/아키텍처 리뷰: 데미지 숫자는 `damage_taken` 신호 + `Tween` 기반, 프레임 루프 추가 없음
	- [x] Enemy 데미지 텍스트 에디터 디버그 미리보기 추가 (`show_debug_preview_in_editor`)
	- [x] Enemy 데미지 텍스트 도트폰트 적용 지원: `damage_font` export로 LabelSettings 폰트 연결
- [ ] Round 별 Enemy 변경
	- [ ] 3단계: Round 전환 트리거(라운드 시작 시 `set_round`) 연결
	- [ ] 4단계: 라운드 매니저/웨이브 매니저 설계 및 구현
	- [ ] 5단계: 10라운드 `round_enemy_scenes` 슬롯(라운드별 다른 Enemy) 최종 연결
- [ ] Enemy 체력 변경
	- [ ] 3단계: 피격/사망 경계값 동작 확인
	- [ ] 3-1단계: death 후 alive 카운트 제외 검증 (`auto_free_on_death_end=false` 케이스 포함)
- [ ] HealthBar 구조 리팩터링 검증
	- [ ] 체력 임계색(초록/노랑/빨강) 회귀 확인
- [ ] RoundManager v1 구현
	- [ ] 7단계: 플레이 검증 (30마리 실패/라운드 전환/10라운드 종료)
- [ ] Enemy 이동속도 변경
	- [ ] 1단계: 경로 이동 Agent 속도 주입 경로 추가
	- [ ] 2단계: Round별 이동속도 값 연결
	- [ ] 3단계: Portal 진입 속도와 Path 이동 속도 밸런스 확인
- [ ] Enemy sprite 변경
	- [ ] 3단계: 애니메이션 상태명/loop/fps 회귀 확인

주간 폴더: `docs/todo/2026-02-4w/`

## 백로그
- [ ] 포탈 스폰 규칙 정리
- [ ] 적 웨이브 설계
- [ ] 무기 업그레이드 플로우 정리
