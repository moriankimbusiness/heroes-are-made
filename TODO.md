# TODO

## 이번 주 (2026-02-4w)]
- [x] 화면 중앙에 Path2D 다이아몬드 경로보다 조금 작은 다이아몬드 "PlayGround" 생성, 여기에 모험가들 생성될 것임
	- [x] "PlayGround" 안에서만 "모험가" 이동가능
- [x] 캐릭터 뽑기
	- [x] 화면 중앙 아래에 "모험가 뽑기" 버튼 추가
	- [x] "모험가 뽑기" 클릭 시 "PlayGround" 중앙에 모험가 생성
	- [x] 모험가들은 각자의 충돌범위가 있어서 겹치지 않도록
	- [x] 모험가 드래그로 위치 이동
- [ ] Enemy non-loop 종료 규칙 회귀 확인 (실행 중 확인 필요)
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

## 오늘 작업 로그 (2026-02-23)
- [x] `scripts/playground/PlayGround.gd` 파싱 에러 수정 (`:=` 타입 추론 실패 구간을 `=`로 전환, 들여쓰기 오류 정리)
- [x] 성능/아키텍처 점검: 프레임 루프(`_process`/`_physics_process`) 신규 추가 없음, UI/게임플레이 책임 경계 영향 없음, Inspector 값 런타임 강제 오버라이드 없음
- [x] Godot CLI 검증 통과: `/mnt/c/Godot_v4.6.1/Godot_v4.6.1-stable_win64_console.exe --headless --path . --quit`
- [x] `scripts/playground/PlayGround.gd` 다중 접촉 드래그 멈춤 완화: 단일 최대 push 대신 합산 push 우선 사용(합산 0에 근접 시 기존 방식 폴백)
- [x] 성능/아키텍처 점검(추가): 이벤트 기반 드래그 흐름 유지, 프레임 루프 신규 없음, Inspector 설정값 런타임 강제 없음
- [x] Godot CLI 재검증 통과: `/mnt/c/Godot_v4.6.1/Godot_v4.6.1-stable_win64_console.exe --headless --path . --quit`
- [x] 드래그 경계 매끄러움 개선 1차: `Hero.gd` 입력/이동 분리(MouseMotion은 target만 갱신, 드래그 중 `_process`에서 연속 해소)
- [x] 충돌 해소 안정화 1차: `PlayGround.gd` margin 분리(`OVERLAP_EPSILON`/`SEPARATION_BIAS`), `resolve_overlaps_smooth` 추가, 랜덤 push 방향 제거
- [x] 성능/아키텍처 점검(추가2): `_process`는 드래그 중에만 활성화(`set_process(true/false)`), UI 책임 분리 영향 없음, Inspector 권한 유지
- [x] Godot CLI 최종 검증 통과: `/mnt/c/Godot_v4.6.1/Godot_v4.6.1-stable_win64_console.exe --headless --path . --quit`
