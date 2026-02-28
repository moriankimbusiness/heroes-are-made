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

out_file="docs/tasks/${task_name}/research.md"
mkdir -p "$(dirname "$out_file")"

if [[ -f "$out_file" ]]; then
  echo "[SKIP] Already exists: $out_file"
  exit 0
fi

today="$(date +%F)"
cat > "$out_file" <<TEMPLATE
# 리서치: [주제 작성]

날짜: ${today}
작업: [요청 요약]

## 목적
- [해결하려는 질문/문제]

## 범위
- In Scope:
- Out of Scope:

## 조사 방법
- [확인한 자료/검증 방법]

## 사실 근거
1. [핵심 사실]
- 근거: [파일 경로/링크/데이터]

## 리스크/가정
- 리스크:
- 가정:

## 결론
- [실행 가능한 결론]

## 출처
- [출처 1]
TEMPLATE

echo "[OK] Created: $out_file"
