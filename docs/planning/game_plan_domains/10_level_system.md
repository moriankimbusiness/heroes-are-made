# 레벨 시스템

## 기본 규칙
- 히어로는 몬스터 처치 시 몬스터 데이터의 EXP를 획득한다.
- 최대 레벨은 30으로 제한한다.
- 레벨별 필요 경험치는 전용 테이블(level_exp_table)로 관리한다.

## 레벨업 성장 규칙
- 수동 스탯 분배는 사용하지 않는다.
- 레벨업 시 스탯은 자동 증가한다.
- 최종 증가량은 종족 성장, 클래스 성장, 유물/버프 보정을 합산해 계산한다.

## 공식
- 레벨업 판정: current_exp >= level_exp_table[current_level]
- 스탯 증가: delta_stat = race_growth[level] + class_growth[level] + bonus_growth[level]
