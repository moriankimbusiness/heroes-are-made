# 결과: PlayGround 리팩토링 및 OOP 리스크 해소

날짜: 2026-03-01
연결 계획: `docs/tasks/playground-role-2026-02-28/plan.md`
연결 리서치: `docs/tasks/playground-role-2026-02-28/research.md`

## 1) 최종 상태
- 완료

## 2) 구현 결과 요약
- 전투 경제 도메인 분리 1차 완료: `BattleEconomy` 서비스 도입, `ShopPanel`의 골드/리롤 상태 소유 제거
- 전투 요약 수집 결합 완화 완료: `BattleSummaryCollector.collect_gold_end()`를 UI 깊은 경로 조회에서 `PlayGround.get_current_gold()` API 경유로 전환
- `PlayGround` 책임 분리 1차 완료: 히어로 스폰 셀 탐색 로직을 `HeroSpawnResolver`로 이관
- 경로 참조 내성 보강 완료: `BattleScreenHost`/`BattleSummaryCollector`에 `Playground`/`PlayGround` 후보 경로 fallback 적용
- 문서 동기화 완료: `TODO.md`, `GAME_PLAN.md`, `docs/tasks/playground-role-2026-02-28/plan.md` 반영

## 3) 수동 회귀 시나리오 결과
- 시나리오 1: 전투 시작 골드/리롤 상태 동기화 확인 (pass)
- 시나리오 2: 무료 리롤 차감 흐름 확인 (pass)
- 시나리오 3: 유료 리롤 비용 증가(`10 -> 20 -> 30`) 확인 (pass)
- 시나리오 4: 카드 구매 성공 시 골드 차감 및 구매완료 상태 반영 확인 (pass)
- 시나리오 5: 골드 부족 시 구매/리롤 차단 및 실패 피드백 확인 (pass)
- 시나리오 6: 전투 종료 `summary["gold_end"]` 반영 확인 (pass)
- 시나리오 7: 종료 사유 3종(`all_rounds_cleared`, `core_destroyed`, `all_heroes_dead`) 회귀 없음 확인 (pass)
- 시나리오 8: 히어로 소환/스폰 셀 동작 회귀 없음 확인 (pass)
- 시나리오 9: 우클릭 이동 명령 마커 표시 동작 확인 (pass)
- 시나리오 10: 사거리 hover 기반 표시/해제 동작 확인 (pass)

## 4) Godot CLI 검증 (R5)
- 상태: pass
- 사용 명령:
```bash
"/mnt/c/Godot_v4.6.1/Godot_v4.6.1-stable_win64_console.exe" --headless --path . --quit
```
- 핵심 출력:
```text
Godot Engine v4.6.1.stable.official.14d19694e - https://godotengine.org
```
- 에러 라인: 없음

## 5) 후속 메모
- 네이밍 통일(`Playground` vs `PlayGround`)의 최종 정책 결정은 별도 합의 과제로 유지한다.
