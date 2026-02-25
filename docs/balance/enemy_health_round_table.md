# Enemy Health Round Table

## Core Rule

- Final enemy HP formula:
- `final_hp = enemy_base_max_health * level_hp_scale * round_multiplier`

Role split:
- `enemy_base` scene: enemy type baseline HP (`base_max_health`)
- level scene (`EnemySpawnController`): level difficulty scale (`level_hp_scale`)
- round table (`round_enemy_health_multipliers`): round progression curve

## Round Multiplier Table (R1~R30)

| Round | Multiplier |
|---:|---:|
| 1 | 1.00 |
| 2 | 1.06 |
| 3 | 1.13 |
| 4 | 1.20 |
| 5 | 1.28 |
| 6 | 1.36 |
| 7 | 1.44 |
| 8 | 1.53 |
| 9 | 1.63 |
| 10 | 1.74 |
| 11 | 1.85 |
| 12 | 1.97 |
| 13 | 2.10 |
| 14 | 2.23 |
| 15 | 2.38 |
| 16 | 2.53 |
| 17 | 2.69 |
| 18 | 2.86 |
| 19 | 3.04 |
| 20 | 3.24 |
| 21 | 3.44 |
| 22 | 3.66 |
| 23 | 3.89 |
| 24 | 4.14 |
| 25 | 4.40 |
| 26 | 4.68 |
| 27 | 4.98 |
| 28 | 5.29 |
| 29 | 5.63 |
| 30 | 5.99 |

## Level Scale Defaults

- Level 1: `level_hp_scale = 1.0`
- Level 2: `level_hp_scale = 2.0`

## Example (base_max_health = 100)

- Level 1, Round 1: `100 * 1.0 * 1.00 = 100`
- Level 1, Round 30: `100 * 1.0 * 5.99 = 599`
- Level 2, Round 1: `100 * 2.0 * 1.00 = 200`
- Level 2, Round 30: `100 * 2.0 * 5.99 = 1198`

## Beyond Round 30

- Keep `use_formula_after_table = true`.
- Use formula growth parameters already provided in `EnemySpawnController`:
- `formula_growth_rate`
- `formula_softcap_rate`
- `formula_softcap_power`
