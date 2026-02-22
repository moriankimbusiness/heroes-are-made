# TODO

## 이번 주 (2026-02-4w)
- [x] Enemy 스폰 포탈 생성 (1차)
	- [x] `portal.tscn` 생성 및 시각 노드 구성
	- [x] `Portal.gd` + `portal_id` export 추가
	- [x] `level.tscn`에 `Portals/Portal_01` 배치
	- [ ] `"spawn_portal"` 그룹 등록 및 조회 확인 (실행 중 확인 필요)
- [x] Enemy 스폰 포탈 애니메이션 추가
- [x] `portal.tscn` Sprite2D -> AnimatedSprite2D 전환
- [x] `idle` 5프레임(0..4), loop, 8 FPS 설정
- [ ] `level.tscn`에서 포탈 자동 재생 확인 (실행 중 확인 필요)
- [x] Enemy 스폰 기능
	- [x] `EnemySpawnController.gd` 추가 (포탈 생성/진입 이동/경로 전환)
	- [x] `level.tscn`에 `SpawnTimer` / `EnemySpawnController` 배치
	- [x] `Path2D/EnemyPathAgentTemplate` 기반 개별 `PathFollow2D` 생성 구조 적용
	- [x] 기존 고정 배치 `PathFollow2D/Enemy` 제거
	- [x] 실행 중 스폰/진입/경로 이동 동작 확인
- [x] Enemy AnimatedSprite2D 전환 (API 유지형)
- [x] Enemy `play_*` / `is_state_finished()` 인터페이스 유지
- [ ] Enemy non-loop 종료 규칙 회귀 확인 (실행 중 확인 필요)
- [ ] Round 별 Enemy 변경 / Enemy 체력, 이동속도, sprite 변경
- [ ] 주간 목표 2

주간 폴더: `docs/todo/2026-02-4w/`

## 백로그
- [ ] 포탈 스폰 규칙 정리
- [ ] 적 웨이브 설계
- [ ] 무기 업그레이드 플로우 정리
