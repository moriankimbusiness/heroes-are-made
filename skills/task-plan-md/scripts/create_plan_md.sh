#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <task-name-kebab-case>"
  exit 1
fi

task_name="$1"
if [[ ! "$task_name" =~ ^[a-z0-9-]+$ ]]; then
  echo "[ERROR] task-name must be lowercase kebab-case (a-z, 0-9, -)."
  exit 1
fi

out_file="docs/tasks/${task_name}/plan.md"
mkdir -p "$(dirname "$out_file")"

if [[ -f "$out_file" ]]; then
  echo "[SKIP] Already exists: $out_file"
  exit 0
fi

today="$(date +%F)"
cat > "$out_file" <<'TEMPLATE'
# 계획: [작업명]

날짜: __TODAY__
작업 슬러그: __TASK_NAME__
연결 리서치: docs/tasks/__TASK_NAME__/research.md
계획 상태: 진행 중

## 1) 목표
- [달성해야 할 결과]

## 2) 범위
### In Scope
- [이번 작업에 포함]

### Out of Scope
- [이번 작업에서 제외]

## 3) 구현 컨텍스트
### 관련 파일/씬/리소스
- [절대/상대 경로]: [변경 이유]

### 의존성 및 순서 제약
- [선행 작업, 순서 제약, 병렬 가능 여부]

## 4) 단계별 작업 (AI Coding Assistant 전용)
> 규칙: 이 섹션에는 AI가 수행할 구현 작업만 작성한다. 사용자 수동 검증 항목은 6) 검증 체크리스트에만 작성한다.

### Phase 0. 기준선/사전 준비
목적:
- [현재 상태 기준선 확정]

작업:
- [ ] [분석/기준선 기록]

산출물:
- [문서/로그/스냅샷 경로]

완료 기준:
- [측정 가능한 완료 조건]

회귀 포인트:
- [이 단계 실패 시 영향 영역]

### Phase 1. 핵심 구현
목적:
- [핵심 기능 구현]

작업:
- [ ] [코드/씬/리소스 변경]

산출물:
- [변경 파일 목록]

완료 기준:
- [기능/구조 완료 조건]

회귀 포인트:
- [잠재 회귀 영역]

### Phase 2. 안정화/정리
목적:
- [검증 자동화, 문서 동기화, 리스크 정리]

작업:
- [ ] [검증 명령 실행]
- [ ] [문서 업데이트]

산출물:
- [검증 결과, 동기화 문서]

완료 기준:
- [pass/fail 또는 blocked 기준]

회귀 포인트:
- [릴리즈 전 확인 항목]

## 5) 단계별 코드 스니펫
### Phase 0 스니펫
대상 파일/실행 위치:
- [예: scripts/system/example.gd]

목적:
- [무엇을 검증/설정하는지]

~~~gdscript
# TODO: 기준선 측정/검증용 코드 스니펫
func _ready() -> void:
    pass
~~~

기대 결과:
- [로그/상태 변화/값]

### Phase 1 스니펫
대상 파일/실행 위치:
- [예: scripts/system/example.gd]

목적:
- [핵심 구현 로직]

~~~gdscript
# TODO: 핵심 구현 코드 스니펫
func apply_feature() -> void:
    pass
~~~

기대 결과:
- [기능 동작 기준]

### Phase 2 스니펫
대상 파일/실행 위치:
- [예: 터미널 명령]

목적:
- [검증/회귀 확인]

~~~bash
# TODO: 검증 명령
# 예: godot headless validation command
~~~

기대 결과:
- [pass/fail 판정 조건]

## 6) 검증 체크리스트 (사용자 수동 QA 전용)
> 규칙: 이 섹션은 사용자가 최종 확인하는 수동 QA 목록이다.

| TC ID | 사전조건 | 검증 절차 | 기대 결과 | 실패 시 디버그 |
| --- | --- | --- | --- | --- |
| QA-01 | [예: 특정 씬/상태 진입] | 1) [행동 1]<br>2) [행동 2] | [정상 동작] | [로그 키워드], [확인 노드/신호], [재현 방법] |
| QA-02 | [예: 데이터 초기화 완료] | 1) [입력/이벤트 발생]<br>2) [화면/상태 확인] | [값/표현 일치] | [값 추적 경로], [브레이크포인트 위치], [원인 분기] |
| QA-03 | [예: 에러 상황 유도 가능] | 1) [실패 케이스 재현]<br>2) [복구 경로 확인] | [안전한 실패/복구] | [null/신호 누락 확인], [폴백 동작 확인] |

## 7) 디버그 테스트 가이드
### 공통 관찰 포인트
- Output 로그 키워드:
- Inspector/Remote SceneTree 확인 노드:
- 신호 연결/수신 확인 포인트:

### 증상별 디버그 분기
1. 증상: [무반응/오동작]
- 확인 순서:
- 원인 후보:
- 조치:

2. 증상: [값 불일치]
- 확인 순서:
- 원인 후보:
- 조치:

3. 증상: [null 참조/경로 실패]
- 확인 순서:
- 원인 후보:
- 조치:

## 8) 리스크 및 대응
- 리스크:
- 대응:

## 9) 완료 선언 조건
- [ ] Phase 작업 체크박스가 모두 완료되었다. (AI 작업)
- [ ] 코드 스니펫이 실제 변경 내용 기준으로 최신화되었다.
- [ ] 사용자 수동 QA(TC)가 모두 Pass로 확인되었다.
- [ ] 산출물/변경 파일 경로가 문서에 명시되었다.
- [ ] 계획 상태를 완료로 갱신했다. (예: 완료 (YYYY-MM-DD))
TEMPLATE

sed -i "s/__TODAY__/${today}/g; s/__TASK_NAME__/${task_name}/g" "$out_file"

echo "[OK] Created: $out_file"
