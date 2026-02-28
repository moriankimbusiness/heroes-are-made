# TODO

## 현재 트랙 (2026-02-28, 토)
- [x] 히어로 사거리 표시 트리거 전환: 클릭 즉시 표시 제거, `HeroInterface > 사거리` 라벨 hover 중에만 타일맵 오버레이 표시
- [x] 사거리 오버레이 렌더 전환: `RangeOverlayDraw(Node2D)` 직접 드로우(무채색 반투명 채움 + 흰색 격자/윤곽선), 텍스처 타일 의존 제거
- [x] 픽셀 렌더 보정: 사거리 선 `1px` 고정 + 안티앨리어싱 제거 + 드로우 좌표 픽셀 스냅 적용
- [x] 사거리 채움 규칙 보정: 히어로가 점유한 중심 타일은 채움(`fill`)에서 제외
- [x] 문서 동기화: `GAME_PLAN.md`, `docs/planning/game_plan_domains/05_hero_design.md`를 hover 기반 사거리 규칙으로 갱신
- [x] TODO 정리: 2026-02-27 완료/검증 섹션을 `docs/todo/2026-02-4w/2026-02-27.md`로 이관
- [x] `AGENTS.md` 운영 규칙 리서치: 파일 길이/구성 적정성, 공식 가이드 비교, 중복/충돌 리스크 진단
- [x] `docs/tasks` 워크플로우 도입: `agents-md-governance-review-2026-02-28`에 `research.md`, `plan.md` 생성 및 리서치 결과 저장
- [x] `docs/tasks` 문서 한글화: `README.md`, `research.md`, `plan.md` 내용을 한국어로 정리
- [x] `plan.md` 상세화: 리서치 기반으로 단계/산출물/검증 체크리스트/리스크 대응까지 포함한 실행 계획으로 확장
- [x] `AGENTS.md` 통합 정리 실행: 규칙군 단일 정본(R1~R7)으로 재구성, 길이 `238 -> 145` 축약
- [x] 운영 참고 분리: `docs/reference/godot_cli_validation.md` 생성 후 `AGENTS.md`에서 링크 참조
- [x] 실행 산출물 기록: `docs/tasks/agents-md-governance-review-2026-02-28/result.md`에 인벤토리/회귀/체크리스트 결과 정리
- [x] 프로젝트 스킬 추가: `skills/task-research-md`, `skills/task-plan-md` 생성 (`docs/tasks/<task>/research.md`, `plan.md` 워크플로우)
- [x] `task-research-md` 강화: 리서치 깊이/세부사항/근거 검증 기준(Research Depth Standard) 규칙 추가
- [x] `task-plan-md` 강화: 계획 깊이/세부 태스크/검증 체크포인트 기준(Planning Depth Standard) 규칙 추가
- [x] 전투 리소스 소유권 교정: `EnemySpawnController` 적 스폰 부모를 레벨 루트로 전환해 전투 종료 시 적 노드가 함께 해제되도록 보장
- [x] 전투 UI 등록 경로 보강: `HeroHUD` 적 등록 훅을 `SceneTree.node_added` 기반으로 전환해 부모 구조 변경과 무관하게 동작하도록 수정
- [x] 전투 종료 경로 정합성 반영: `BattleScreenHost`의 미사용 `game_failed` 연결 제거 및 `GAME_PLAN.md` 종료 판정 근거 문구 동기화

## 다음 작업
- [ ] 챕터 확장 2차: 최종보스 클리어 후 다음 챕터 월드맵 연계
- [ ] 챕터 준비 2차: 편성/장비관리 UI를 실제 히어로/인벤토리 데이터와 연결

## 성능/아키텍처 체크 (2026-02-28, 토)
- [x] 오버레이 갱신은 기존 선택/hover/타일변경 이벤트에서만 `queue_redraw()` 호출(신규 `_process`/`_physics_process` 폴링 없음)
- [x] 드로우 데이터는 셀 배열 전달 기반이며 프레임 루프에서 리소스 로드/노드 탐색 반복 없음
- [x] 선 렌더는 1px/무-AA 고정, 좌표 스냅으로 서브픽셀 블러를 방지
- [x] 중심 타일 제외는 오버레이 셀 빌드 단계 조건 분기로 처리(추가 프레임 루프/노드 탐색 없음)
