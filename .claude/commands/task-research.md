# Task Research MD

`docs/tasks/<task-name>/research.md` 리서치 문서를 생성하거나 갱신한다.

## 입력

사용자 요청: $ARGUMENTS

## Workflow

1. **task-name 결정** — lowercase kebab-case.
   - 사용자가 명시한 slug 우선.
   - `docs/tastks` 오타는 `docs/tasks`로 정규화.

2. **디렉토리 생성** — `docs/tasks/<task-name>/` 없으면 생성.

3. **research.md 생성 또는 갱신**
   - 파일이 없으면 `skills/task-research-md/scripts/create_research_md.sh <task-name>` 실행 후 내용 채움.
   - 파일이 이미 있으면 기존 검증된 내용 보존, 날짜 기록과 함께 섹션 추가/갱신.

4. **필수 섹션 구조**
   - 목적
   - 범위
   - 조사 방법
   - 사실 근거
   - 리스크/가정
   - 결론
   - 출처

5. **언어** — 사용자의 요청 언어에 맞춤 (한국어 요청 시 한국어 작성).

## Research Depth Standard

- 표면적 조사가 아닌 **깊이 있는 조사** 수행.
- 구체적 세부사항, 엣지 케이스, 가정, 트레이드오프 커버.
- 1차 증거 우선, 핵심 주장마다 정확한 출처 명시.
- 가능한 경우 구체적 숫자, 날짜, 파일 경로, 범위 경계 포함.
- 출처 간 일관성 검증 — 충돌 시 충돌과 해결 과정 문서화.
- 알려진 것, 추론한 것, 불확실한 것을 명시적으로 구분.
- 요약에서 끝내지 않고 실행 가능한 발견과 후속 점검 항목 제공.

## Guardrails

- 리서치 내용은 `docs/tasks/<task-name>/research.md`에 작성 (사용자가 추가 파일을 요청하지 않는 한).
- 기존 검증된 노트 보존, 수정 시 날짜 기록 추가.
