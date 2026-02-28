# 계획: 전투 승리 최종 라운드 Editor 설정 + 레벨별 Enemy JSON 테이블화

날짜: 2026-02-28
연결 리서치: `docs/tasks/roundmanager-round-success-condition-2026-02-28/research.md`
계획 상태 (2026-02-28): 진행 중 (핵심 결정 확정 완료, 구현 대기)
완료 상태 (2026-02-28): 미완료
우선순위: 높음

## 1) 목표
- 전투 승리 최종 라운드(`final_round`)는 Editor(Inspector)에서 직접 설정한다.
- 라운드 데이터 source를 Inspector 배열에서 레벨별 JSON로 전환한다.
- JSON 데이터 구조는 `rounds`/`health_multiplier`를 제거하고 `enemies` 중심으로 단순화한다.
- 적 최대 체력은 JSON 배율이 아니라 enemy scene의 `max_health`(또는 `base_max_health`)를 사용한다.

## 2) 범위
### In Scope
- `scripts/round/RoundManager.gd`
- `scripts/round/RoundSystem.gd`
- `scripts/spawn/EnemySpawnController.gd`
- `scenes/round/round_system.tscn`
- `scenes/levels/level_base.tscn`, `scenes/levels/level_01.tscn`, `scenes/levels/level_02.tscn`
- 신규 JSON(레벨별 분리): `assets/data/round/round_table_level_01.json`, `assets/data/round/round_table_level_02.json`
- `GAME_PLAN.md`, `TODO.md` (구현 완료 시 동기화)

### Out of Scope
- 적 AI/전투 시스템 전면 리워크
- 전투 UI 레이아웃/아트 변경
- 아이템/경제/월드맵 시스템 변경
- 에디터 플러그인 제작

## 3) 선행 합의/결정 포인트
- [x] 최종 라운드 authoritative source 확정
- 결정: `RoundSystem` export(`final_round`) -> `RoundManager` 주입
- [x] JSON 파일 운영 정책 확정
- 결정: 레벨별 분리(`round_table_level_01.json`, `round_table_level_02.json`)
- [x] JSON 스키마 1차 확정
- 결정: 루트 키는 `enemies` 사용, `rounds` 제거
- [x] 체력 데이터 정책 확정
- 결정: JSON `health_multiplier` 제거, enemy scene 체력값 사용
- [x] 레벨 파생 씬 초기 정책 확정
- 결정: `level_01`, `level_02` 라운드 관련 override 제거 후 `level_base` 기준으로 테스트
- [x] Inspector 배열 초기 정책 확정
- 결정: `round_spawn_counts`, `round_enemy_health_multipliers` 비우고 JSON only로 진행
- [x] 공식 체력 파라미터 정책 확정
- 결정: `use_formula_after_table` + `formula_*` 파라미터/로직 삭제
- [x] 마이그레이션 정책 확정
- 결정: legacy fallback 미허용, JSON 경로 미설정/로드 실패 시 fail-fast
- [x] 라운드별 몬스터 데이터 source 확정
- 결정: Inspector `round_enemy_scenes` 대신 JSON `enemies[].scene_path` 사용
- [x] 스폰 전략 확정
- 결정: 하이브리드(`spawn_plan` 있으면 순서형, 없으면 `enemies` 기반 가중치 랜덤)
- [x] 가중치 정책 확정
- 결정: `enemies[].weight` 사용(0 초과)
- [x] RNG 정책 확정
- 결정: payload `seed` + `node_id` 조합으로 deterministic random 적용
- [x] `spawn_count` 의미 확정
- 결정: `enemies[].spawn_count`는 "해당 라운드의 enemy별 목표 수량"이다.

## 3-1) JSON 파일 분리 확정 근거
- 장점:
- 레벨별 테스트/튜닝/롤백이 쉽다.
- 병행 수정 충돌 범위가 작다.
- 레벨별 난이도 실험을 독립적으로 관리할 수 있다.
- 단점:
- 파일 수 증가로 관리 포인트가 늘어난다.
- 공통 규칙 변경 시 여러 파일 수정이 필요할 수 있다.
- 결론:
- 현재 요구(레벨별 테스트 중심) 기준으로 레벨별 분리가 적합하다.

## 3-2) JSON 스키마 초안 (확정 반영)
```json
{
  "version": 1,
  "enemies": [
    { "id": "orc", "scene_path": "res://scenes/enemies/variants/enemy_orc.tscn", "spawn_count": 20, "weight": 70.0 },
    { "id": "orc2", "scene_path": "res://scenes/enemies/variants/enemy_orc2.tscn", "spawn_count": 10, "weight": 30.0 }
  ],
  "spawn_plan": [
    { "round": 1, "enemy_id": "orc", "count": 8 },
    { "round": 1, "enemy_id": "orc2", "count": 2 },
    { "round": 2, "enemy_id": "orc", "count": 6 },
    { "round": 2, "enemy_id": "orc2", "count": 4 }
  ]
}
```
- 검증 규칙:
- `enemies`는 비어 있으면 안 된다.
- `scene_path`는 `PackedScene` 로드 가능해야 한다.
- `spawn_count`는 1 이상 정수여야 한다.
- `weight`는 0 초과 숫자여야 한다.
- `spawn_count`는 라운드당 수량이며, fallback 랜덤 모드에서도 enemy별 라운드 목표 수량으로 사용한다.
- `spawn_plan`은 선택 키이며, 존재하면 순서형 스폰 규칙으로 사용한다.
- `spawn_plan.round`는 1 이상 `final_round` 이하여야 한다.
- `spawn_plan.enemy_id`는 반드시 `enemies[].id` 중 하나와 일치해야 한다.
- `spawn_plan.count`는 1 이상 정수여야 한다.
- `final_round`는 승리 라운드 판정 전용이며, `enemies` 길이와 직접 연결하지 않는다.

## 3-3) 스폰 전략 확정안
- 옵션 A. `enemies` 목록 랜덤 스폰
- 장점: 데이터 구조 단순, 적 풀 확장 쉬움, 레벨 다양성 높음.
- 단점: 라운드별 연출/난이도 곡선을 정밀 제어하기 어렵다.
- 옵션 B. 순서 기반 스폰 플랜
- 장점: 라운드별 연출과 난이도 제어가 명확하다.
- 단점: 데이터 구조가 길어지고 유지비가 증가한다.
- 옵션 C. 하이브리드
- 장점: 기본은 단순하게 유지하면서 필요한 레벨에만 순서형 정밀 제어를 추가할 수 있다.
- 단점: 모드가 2개라 초기 검증 케이스가 늘어난다.
- 확정안:
- 옵션 C를 채택한다.
- `spawn_plan`이 있으면 순서형 우선 적용한다.
- `spawn_plan`이 없으면 `enemies[].weight` 기반 랜덤을 사용한다.
- `spawn_plan`이 없을 때도 `enemies[].spawn_count`(라운드당 수량)를 적용한다.
- 랜덤은 payload `seed` + `node_id` 기반으로 재현 가능해야 한다.

## 4) 단계별 작업 (Phase)
### Phase 0. 설계 고정 및 계약 정의
- [ ] 기존 승리 계산 경로(`get_configured_round_count`) 사용 지점 전수 확인
- [x] 최종 라운드 계약 정의: `final_round >= 1`
- [x] JSON 스키마 계약 정의: `enemies[]` + 선택 `spawn_plan[]`
- [x] 마이그레이션 정책 확정: legacy fallback 비허용(JSON 필수)
- [x] 체력 정책 확정: enemy scene 체력 사용
- [x] 스폰 전략 확정: 하이브리드(+가중치 랜덤)

산출물:
- [x] 본 `plan.md` 결정 포인트 체크 완료
- [x] JSON 샘플 스키마 초안 문서화

완료 기준:
- [ ] 구현 전 단일 스폰 전략이 고정됨

### Phase 1. 최종 라운드 Editor 설정 경로 구축 (Editor-first)
- [ ] `RoundSystem`에 `final_round` export 추가 및 Inspector 설정 포인트 생성
- [ ] `level_base.tscn`에 `final_round` 값 명시
- [ ] `RoundSystem -> RoundManager` 주입 연결
- [ ] `RoundManager` 승리 판정에서 `EnemySpawnController.get_configured_round_count()` 의존 제거
- [ ] `level_01.tscn`, `level_02.tscn` 라운드 관련 override 제거

산출물:
- [ ] 수정: `scripts/round/RoundSystem.gd`
- [ ] 수정: `scripts/round/RoundManager.gd`
- [ ] 수정: `scenes/round/round_system.tscn`
- [ ] 수정: `scenes/levels/level_base.tscn`, `scenes/levels/level_01.tscn`, `scenes/levels/level_02.tscn`

완료 기준:
- [ ] Inspector 값 변경만으로 승리 라운드가 바뀐다.

### Phase 2. Enemy JSON 로더 도입 (Script-second)
- [ ] `EnemySpawnController`에 레벨별 JSON 경로 export 추가 (`@export_file("*.json")`)
- [ ] JSON 로드/파싱 로직 추가 (`enemies` 구조 기준)
- [ ] `scene_path` 로드 검증 + `spawn_count` 검증 추가
- [ ] `weight` 파싱/검증 추가
- [ ] 로드 실패 시 fail-fast 처리
- [ ] payload `seed` + `node_id` 기반 RNG 초기화 추가
- [ ] `use_formula_after_table`, `formula_*`, `round_enemy_health_multipliers` 관련 로직 제거
- [ ] `round_spawn_counts` 의존 로직 제거

산출물:
- [ ] 수정: `scripts/spawn/EnemySpawnController.gd`
- [ ] 신규: `assets/data/round/round_table_level_01.json`
- [ ] 신규: `assets/data/round/round_table_level_02.json`

완료 기준:
- [ ] 스폰 구성은 JSON 편집만으로 반영된다.
- [ ] 체력은 enemy scene 설정값으로만 반영된다.

### Phase 3. 스폰 전략 구현 및 정합성 보강
- [ ] 확정된 스폰 전략(하이브리드+가중치 랜덤) 구현
- [ ] 잘못된 `scene_path`에 라인/인덱스 포함 에러 메시지 보강
- [ ] `round_enemy_scenes` 경로 비사용 처리(제거 또는 명시 deprecate)

산출물:
- [ ] 수정: `scripts/spawn/EnemySpawnController.gd`
- [ ] 필요 시 수정: `docs/balance/enemy_health_round_table.md` (삭제/대체 안내)

완료 기준:
- [ ] 스폰 정책이 문서와 코드에서 일치한다.

### Phase 4. 에디터 데이터 이관 및 씬 반영
- [ ] `level_base` 기존 배열(`round_spawn_counts`, `round_enemy_health_multipliers`) 비우기
- [ ] `level_01`, `level_02` override 제거 반영
- [ ] 레벨별 JSON 경로 연결
- [ ] 레벨별 테스트 중 수치 변경이 JSON에서만 이루어지는지 확인

산출물:
- [ ] 수정: `scenes/levels/level_base.tscn`
- [ ] 수정: `scenes/levels/level_01.tscn`
- [ ] 수정: `scenes/levels/level_02.tscn`

완료 기준:
- [ ] 씬 Inspector 기준 데이터 소스 혼선이 없다.

### Phase 5. 검증 및 문서 동기화
- [ ] 시나리오 검증 1: 최종 라운드 직전 승리 emit 없음
- [ ] 시나리오 검증 2: 최종 라운드 전이 시 `all_rounds_cleared` 1회 emit
- [ ] 시나리오 검증 3: `final_round` 변경 시 의도 라운드에서 승리
- [ ] 시나리오 검증 4: JSON 경로/타입 오류 시 fail-fast
- [ ] Godot CLI 검증 실행 (R5)
- [ ] `GAME_PLAN.md`, `TODO.md` 동기화

검증 명령:
- [ ] `/mnt/c/Godot_v4.6.1/Godot_v4.6.1-stable_win64_console.exe --headless --path . --quit`
- [ ] WSL 소켓 오류 시 PowerShell fallback 재실행

## 5) 검증 체크리스트
- [ ] 승리 조건은 `final_round` Inspector 값만으로 결정된다.
- [ ] 라운드 스폰 데이터는 JSON `enemies`가 단일 소스다.
- [ ] 랜덤 스폰 시 `enemies[].weight`가 정상 반영된다.
- [ ] 동일 `seed`/`node_id` 입력에서 스폰 결과가 재현된다.
- [ ] `health_multiplier` 없이 enemy scene 체력값만 사용한다.
- [ ] JSON 스키마 오류(누락 키/타입 오류/경로 오류) 시 즉시 에러가 발생한다.
- [ ] `BattleScreenHost` 승리 종료(`all_rounds_cleared`) 회귀가 없다.
- [ ] 기존 패배 종료(`core_destroyed`, `all_heroes_dead`) 회귀가 없다.
- [ ] Godot CLI 결과가 pass이거나 blocked 사유가 정책 형식으로 보고된다.

## 6) 리스크/대응
- 리스크: `final_round`와 스폰 전략이 분리되면서 난이도 곡선이 의도와 다를 수 있다.
- 대응: 레벨별 JSON 튜닝 + 수동 시나리오 검증을 Phase 5에 고정한다.

- 리스크: JSON 경로 오타/리소스 누락으로 런타임 실패 가능.
- 대응: 초기화 시 fail-fast + 파일 경로/인덱스 포함 에러 메시지 제공.

- 리스크: 스폰 전략을 늦게 확정하면 구현 재작업이 발생한다.
- 대응: 확정 완료(하이브리드+가중치). 구현은 확정 계약만 따른다.

## 7) 가정/미해결 질문
- [x] `final_round` 운영 정책 확정: 레벨별 개별값(Inspector override)
- [x] JSON 파일 운영 정책 확정: 레벨별 분리
- [x] 체력 정책 확정: `health_multiplier` 제거, enemy scene 체력 사용
- [x] 몬스터 데이터 source 확정: JSON `enemies[].scene_path`
- [x] 스폰 전략 확정: 하이브리드(`spawn_plan` 우선 + `enemies[].weight` 랜덤 fallback)
- [x] RNG 정책 확정: payload seed 기반 deterministic random
- [x] `spawn_count` 의미 확정: 라운드당 수량

## 8) 완료 선언 조건
- [ ] Phase 0~5 체크 항목이 모두 `[x]`로 갱신됨
- [ ] 최종 라운드 변경이 Inspector 조작만으로 동작함
- [ ] 스폰 데이터가 JSON `enemies`로만 관리됨
- [ ] 검증 결과(pass/fail/blocked, 사용 명령, 핵심 에러 라인)가 보고됨
- [ ] `GAME_PLAN.md`, `TODO.md` 동기화 완료
- [ ] 본 문서 상태 라인이 `계획 상태 (YYYY-MM-DD): 완료`로 갱신됨
