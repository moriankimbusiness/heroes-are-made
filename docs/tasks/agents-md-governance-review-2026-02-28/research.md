# 리서치: AGENTS.md 길이 및 내용 적정성 검토

날짜: 2026-02-28  
작업: 루트 `AGENTS.md`가 "항상 로드되는 에이전트 지침"으로서 적절한 분량/구조인지 평가

## 범위

- 로컬 파일 분량/구조 정량 분석
- 1차 출처(공식 문서) 기준 비교
- 중복/충돌/운영 부담 리스크 식별

## 로컬 파일 측정값

대상 파일: `/mnt/d/04.GameWorkSpaces/00.GodotProjects/heroes-are-made/AGENTS.md`

- 줄 수: 238
- 단어 수: 1,685
- 바이트 수: 13,192
- H2 섹션 수: 16
- H3 섹션 수: 5
- 불릿 라인 수: 142
- `Mandatory` 표기 수: 14

## 로컬 분석 핵심 관찰

1. 하드 제한(사이즈)은 안전함.
- Codex 기본 프로젝트 문서 상한(32 KiB)보다 충분히 작음.
- 현재 상태에서 잘림(truncation) 리스크는 낮음.

2. 항상 로드되는 정책 문서치고는 밀도가 높음.
- 동일한 규칙군이 여러 섹션에서 반복됨:
  - Editor 우선/권한
  - Script override 제한
  - CLI 검증 조건
  - TODO 기반 작업 규칙
- 반복은 해석 비용을 올리고, 향후 수정 시 누락/불일치 가능성을 키움.

3. 중복 규칙 군집이 실제로 존재함.
- Editor/Script 권한 규칙이 다수 섹션에 중첩.
- CLI 검증 조건도 2개 이상 섹션에 분산.
- TODO 워크플로우도 여러 위치에서 부분 중복.

4. 정책과 참고 데이터가 한 파일에 섞여 있음.
- 강제 정책과 환경 참고 정보(실행 경로, fallback 명령, 과거 환경 메모)가 공존.
- 단기적으로는 편리하나, 장기적으로는 핵심 지침 문서의 가독성과 유지보수성 저하 가능.

## 외부 1차 출처 기반 결과

1. OpenAI Codex 문서
- AGENTS 계열 프로젝트 문서 탐색/적용 규칙이 존재.
- `project_doc_max_bytes` 기본값은 32768(32 KiB).
- 시사점: 현재 파일은 "크기 적합"이나, 품질 평가는 크기 외 요소(중복/명확성)까지 필요.

2. OpenAI Codex Harness Engineering
- 코어 AGENTS는 간결하게 유지하고, 장문/가변 상세는 별도 문서로 분리 권장.
- 실무적으로 코어 규칙을 비교적 짧게 유지하는 패턴 제시.

3. GitHub Copilot 공식 문서
- 중첩 지침은 가까운 컨텍스트 우선.
- 중복/충돌 지시가 많을수록 결과 안정성이 낮아질 수 있음.
- 시사점: 동일 규칙은 단일 출처로 정규화하는 편이 안전.

4. Anthropic Claude Code 문서
- 세션 로드형 메모리/지침은 "구체적 + 간결" 원칙 권장.
- 과도한 장문 지침은 해석 일관성을 떨어뜨릴 수 있음.

5. agents.md 관례 문서
- 명령형, 간결, 스캔 친화 구조를 권장.

## 종합 평가

현재 `AGENTS.md` 평점:
- 정책 의도 명확성: 높음
- 유지보수성: 중간
- 반복 사용 시 스캔성: 중하
- 크기 안전성: 높음

결론:
- 시스템 한계 관점에서는 적정.
- 운영 품질 관점에서는 다소 과밀.
- 전체 재작성보다 "중복 통합"이 우선.

## 권장 정리 방향

1. 규칙군별 단일 정본 섹션 유지
- Editor 권한 + Script 책임 경계
- CLI 검증 트리거/보고
- TODO 워크플로우

2. 참고성 상세를 AGENTS 코어에서 분리
- 실행 파일 경로 표
- 긴 fallback 명령 예시
- 날짜성 환경 메모

3. AGENTS를 실행 규칙 시트로 유지
- 이 저장소 기준 120~160줄 수준 권장
- `must` 정책은 유지, 설명 중복은 축약

## 후속 정리의 완료 기준 제안

- 동일 강제 규칙이 여러 섹션에 중복되지 않음
- AGENTS 크기가 16 KiB 이하(권장 8~10 KiB)
- 분리된 상세 문서 위치가 AGENTS에 연결됨
- CLI 검증 정책의 단일 출처 섹션이 존재함

## 실행 결과 링크 (2026-02-28)

- 실행 보고: `docs/tasks/agents-md-governance-review-2026-02-28/result.md`
- 통합본 정책: `AGENTS.md`
- 분리 참고 문서: `docs/reference/godot_cli_validation.md`

## 출처

- https://developers.openai.com/codex/prompting#agentsmd-files
- https://developers.openai.com/codex/config#project_doc_max_bytes
- https://openai.com/index/codex-harness-engineering/
- https://docs.github.com/en/copilot/customizing-copilot/adding-repository-custom-instructions-for-github-copilot
- https://docs.anthropic.com/en/docs/claude-code/memory
- https://agents.md/
