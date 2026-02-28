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
cat > "$out_file" <<TEMPLATE
# 계획: [작업명]

날짜: ${today}
연결 리서치: docs/tasks/${task_name}/research.md
계획 상태: 진행 중

## 1) 목표
- [달성해야 할 결과]

## 2) 범위
### In Scope
- [이번 작업에 포함]

### Out of Scope
- [이번 작업에서 제외]

## 3) 단계별 작업
### Phase 0. 준비
- [ ] 사전 확인

### Phase 1. 구현
- [ ] 핵심 구현

### Phase 2. 검증
- [ ] 결과 검증

### Phase 3. 마감
- [ ] 문서/기록 반영

## 4) 검증 체크리스트
- [ ] 기능/요구사항 충족
- [ ] 회귀 리스크 점검
- [ ] 관련 문서 반영

## 5) 리스크 및 대응
- 리스크:
- 대응:

## 6) 완료 선언 조건
- 체크리스트 전 항목 완료
- 산출물 경로 명시
- 계획 상태를 완료로 갱신
TEMPLATE

echo "[OK] Created: $out_file"
