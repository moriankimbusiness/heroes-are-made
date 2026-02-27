# 런 진행 플로우 및 월드맵

## 진행 단위 및 상태 전이
- 진행 단위는 챕터 단위 런이다.
- 기본 순환은 메인화면 → 챕터 시작 준비 → 게임월드(경로 선택) → 노드 전용 화면 → 노드 결과 요약 → 게임월드 복귀다.
- 챕터 최종보스 클리어 시 챕터 결과 화면으로 이동한다.
- 전투 패배 시 런 실패 결과 화면으로 이동한다.
- 실패 노드 재도전은 허용하지 않는다.

## 월드맵 생성 규칙
- 시작 노드 1개, 최종 노드 1개를 고정한다.
- 시작과 최종 사이 중간 깊이는 깊이별 1~3개 노드를 랜덤 배치한다.
- 플레이어는 현재 위치와 연결된 다음 노드 중 1개만 선택할 수 있다.
- 월드맵 정보(노드 타입/연결)는 챕터 시작 시 전체 공개한다.

## 깊이 규칙
- D0: 시작 노드 1개
- D1~D6: 깊이별 1~3개 랜덤
- D7: 최종보스 노드 1개

## 노드 타입 배치 규칙
- D4에 중간보스 노드를 정확히 1개 배치한다.
- D7은 최종보스 노드로 고정한다.
- 마을 노드는 D2~D5 구간에서 챕터당 최소 1회 보장한다.
- 동일 깊이에서 노드가 3개일 때 동일 타입 3중복은 금지한다.

## 경로 연결 규칙
- 각 노드는 다음 깊이의 인접 인덱스(-1, 0, +1)를 우선 연결 후보로 사용한다.
- 모든 노드는 최소 1개 진입 경로와 최소 1개 진출 경로를 가진다.
- 고립 노드는 생성하지 않는다.

## 노드 타입 정의
- 일반 전투 노드: 일반 적 웨이브 전투
- 중간보스 노드: 강화된 적/패턴 전투
- 최종보스 노드: 챕터 클리어 조건 전투
- 아이템 획득 노드: 장비/카드/유물 보상 선택
- 마을 노드: 회복/강화/상점/정비
- 이벤트 노드: 랜덤 선택지/리스크-보상 이벤트

## 노드 해소 규칙
- 전투 계열 노드는 전투 플레이 화면으로 전환한다.
- 아이템 획득 노드는 3개 제시 후 1개 선택을 기본으로 한다.
- 마을 노드는 회복/강화/상점/정비완료 흐름으로 처리한다.
- 이벤트 노드는 선택지 처리 후 결과를 확정한다.
- 모든 노드는 해소 후 결과 요약을 거쳐 월드맵으로 복귀한다.

## 이벤트 계약
- run_started(run_id, chapter_id)
- world_node_selected(node_id, node_type)
- battle_started(node_id, encounter_id)
- battle_finished(node_id, victory, summary)
- world_node_resolved(node_id, result)
- chapter_cleared(chapter_id)
- run_failed(reason, chapter_id, node_id)
- run_cleared(run_id)

## 데이터 모델 계약
- RunState: run_id, chapter_index, gold, party_state, inventory_state, relics, seed
- ChapterState: chapter_id, world_graph, current_node_id, visited_nodes, is_chapter_cleared
- WorldNodeData: node_id, depth, node_type, position, reward_profile, flags
- WorldEdgeData: from_node_id, to_node_id
- NodeResolutionResult: node_id, result_type, hp_delta, gold_delta, granted_rewards, consumed_resources, next_state

## 저장/복구 정책
- 노드 선택 확정 직후 ChapterState를 저장한다.
- 노드 보상 선택 확정 직후 RunState를 저장한다.
- 선택 미확정 상태는 저장 반영하지 않는다.

## 현재 범위 제외
- 메타 진행(영구 성장/영구 해금)
- 챕터별 상세 밸런스 수치 테이블
- 전투 플레이 화면 내부 세부 로직 재설계
