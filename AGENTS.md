# Agent Working Rules (Project-Specific)

## Godot Workflow Priority (Mandatory)

For any Godot scene/gameplay setup request, follow this order strictly:

1. **Editor-first instructions**
   - Explain what to set in the Godot editor first (node selection, Inspector values, scene tree actions, save step).
   - These editor steps must be provided before any script guidance.
   - If a value can be authored in the editor, it must be authored in the editor first.

2. **Script-second instructions**
   - After editor steps, explain only the script part that is still needed.
   - Script must not override editor-authored values unless the user explicitly asks for runtime override behavior.
   - Script scope is limited to trigger/feature logic unless runtime override is explicitly requested by the user.

## Editor-Authoritative Policy (Mandatory)

- Treat the Godot editor as the single source of truth for authorable data.
- Anything configurable in editor must be authored in editor:
  - node hierarchy and scene composition
  - Inspector-authored values and resource references
  - animation assets/settings (`SpriteFrames`, animation names, FPS, loop, autoplay)
  - visual/audio/collision setup
- Do not replace editor-authored setup with script-driven data construction by default.

## Script Responsibility Boundary (Mandatory)

- Script is responsible for trigger and feature behavior only.
- Allowed in script:
  - state transition triggers (e.g., `play_*` calls)
  - signal connection/handling
  - gameplay systems (spawn/combat/round rules)
  - event-driven runtime reactions
- Not allowed in script by default:
  - dynamic creation of animation frame assets meant to be editor-authored
  - hardcoding animation tables/FPS/loop in place of editor-authored animation data
  - resetting editor-authored values at runtime

## Prohibited Script Overrides (Mandatory)

- Unless the user explicitly requests runtime override behavior, prohibit:
  - forcing animation/FPS/loop/autoplay from script
  - replacing editor animation assets with runtime-generated equivalents
  - ignoring inspector-authored values through script hardcoding

## Export Variable Description Policy (Mandatory)

- Every exported inspector field must have editor-visible context.
- For `.gd` scripts, document exported fields using inspector-visible labels:
  - `@export_group`, `@export_subgroup`, or `@export_category`
  - include concise purpose/unit context in the group/category text when useful
- For per-property hover tooltips in Inspector, add `##` doc comments immediately above each `@export* var` declaration.
- Do not rely only on regular comments (`# ...`) for exported field explanations; use Inspector-visible labels and doc comments.
- For any new or changed exported variable in script work, apply both in the same change:
  - place the variable under an appropriate `@export_group`/`@export_subgroup`/`@export_category`
  - add a `##` doc comment immediately above that exported variable
- When adding or changing `@export` fields, update grouping/description labels in the same task.

## Action Animation Restart Policy (Mandatory)

- For explicit action triggers (`play_*` style calls), restart the target animation by default even when the state is unchanged.
- Implement this in script trigger methods (for example, by using a forced state transition), not by modifying editor-authored animation resources.
- Do not restart animations from per-frame loops unless frame-by-frame behavior is explicitly required.
- Scope:
  - Entity gameplay actions (Hero/Enemy attack, hurt, death, walk triggers) follow restart-on-action as the default behavior.
  - If a specific action must preserve current playback progress, document that exception in `TODO.md`.

## Implementation Design Gate (Mandatory)

Before implementing any new feature, confirm these design constraints first.

1. Responsibility split
- Gameplay/domain logic belongs in entity scripts (for example, `Enemy.gd`).
- UI rendering logic belongs in UI-node scripts (for example, `EnemyHealthBar.gd`).
- Entity scripts must not directly control UI style/color/presentation.
- Entity scripts should emit state via signals (for example, `health_changed`, `died`).

2. Scene inheritance consistency
- If base/variant structure exists, each variant must instance/inherit the base scene.
- Add common nodes only in base scenes.
- Keep variants limited to required overrides.
- After base changes, verify inherited node visibility/behavior in each variant.

3. Implementation order
- Editor setup first (node tree, Inspector values, resource links).
- Script changes second, only for runtime trigger/feature behavior.
- Scripts must not override editor-authored values by default.

4. Definition of done
- Feature behavior works.
- Architecture is validated (responsibility split and inheritance reflection).
- Performance structure is reviewed (frame-loop necessity, event-driven alternatives, hot-path cost).
- `TODO.md` is updated.
- Regression check points are documented.
- Godot CLI validation is executed and result is recorded in the response **only when the task includes Godot development changes** (scene/script/resource/project files).

## OOP & Optimization Principles (Mandatory)

### OOP 원칙 준수

모든 스크립트/시스템 설계 시 다음 OOP 원칙을 반드시 적용한다.

- **단일 책임(SRP)**: 클래스/노드 하나는 하나의 책임만 가진다.
  - 예: `Enemy.gd`는 전투 도메인 로직만 담당, UI 렌더링은 별도 노드가 담당.
- **캡슐화(Encapsulation)**: 내부 상태는 외부에 직접 노출하지 않는다.
  - 상태 변경은 명시적 메서드(`take_damage()`, `heal()` 등)를 통해서만 허용.
  - 외부에서 직접 멤버 변수를 쓰는 코드(예: `enemy.hp -= 10`)는 금지.
- **상속 vs 컴포지션**: 공통 행동은 베이스 씬/스크립트로 올리고, 변형은 오버라이드로 처리.
  - 불필요한 다중 상속 대신 컴포지션(노드 조합, 신호 기반 협력)을 우선 고려.
- **신호(Signal) 기반 의존 역전**: 하위 노드가 상위 노드를 직접 참조하는 대신 신호로 통보.
  - 도메인 엔티티(Entity)는 상태 변화를 신호로 방출하고, UI/시스템이 구독.

### 최적화 원칙 준수

모든 구현 시 다음 최적화 지침을 반드시 고려한다.

- **핫패스(Hot Path) 비용 최소화**:
  - `_process` / `_physics_process` 내부에서 `get_node*`, 동적 할당, 대형 배열 재생성, 문자열 포맷 반복 금지.
  - 캐싱 패턴 사용: 노드 참조는 `_ready()`에서 한 번만 취득 후 멤버 변수에 저장.
- **이벤트/신호 우선**:
  - 상태 변화 감지는 폴링(per-frame 비교) 대신 신호/이벤트로 처리.
- **불필요한 재계산 방지**:
  - 변하지 않는 값은 상수(`const`) 또는 `_ready()` 초기화로 한 번만 계산.
  - 동일 프레임 내 중복 연산은 로컬 변수에 캐싱.
- **메모리/오브젝트 수명 관리**:
  - 임시 노드/오브젝트는 사용 후 즉시 해제(`queue_free()`).
  - 오브젝트 풀(Object Pool)이 필요한 반복 생성 시 풀 패턴 검토.
- **구현 전 최적화 검토 질문**:
  1. 이 로직이 매 프레임 실행되어야 하는가? → 아니라면 이벤트 기반으로 전환.
  2. 반복 호출되는 함수에서 불필요한 할당/해제가 발생하는가?
  3. 데이터 구조가 접근 패턴에 적합한가? (Dictionary vs Array 등)

## Godot Performance & Architecture Review Gate (Mandatory)

For every gameplay/UI/script change, run a lightweight performance/architecture review before completion.

### Required checks

- Avoid per-frame updates by default:
  - `_process` / `_physics_process` are allowed only when frame-by-frame behavior is truly required.
  - If event/signal-based update is possible, prefer event/signal-based update.
- Keep UI event-driven:
  - UI visibility/text/state updates should be triggered by signals or explicit state-change methods.
- Avoid high-cost work in frame loops:
  - No repeated `get_node*`, resource loading, large array rebuilds, or avoidable string-heavy formatting inside frame callbacks.
- Preserve editor-authored authority:
  - Do not override Inspector-authored values at runtime unless explicitly requested.

### Completion criteria

- Feature works functionally.
- Performance/architecture checklist reviewed and recorded.
- Godot CLI validation executed and result recorded in the response (only for Godot development changes).
- `TODO.md` updated with work/review outcome (CLI 검증 결과 값은 `TODO.md`에 기록하지 않는다).

## Godot CLI Validation (Mandatory)

- Run Godot CLI validation before completion **only when the task includes Godot development changes**.
- Godot development changes include updates to `.tscn`, `.tres`, `.res`, `.gd`, `project.godot`, gameplay/UI/runtime logic, or other in-engine runtime assets/settings.
- Documentation-only changes (for example `AGENTS.md`, `GAME_PLAN.md`, `TODO.md`, `README.md`, design notes) do not require CLI validation.
- Do not write Godot CLI validation outcomes to `TODO.md`; report them only in the assistant response.
- Preferred command (WSL path):
  - `/mnt/c/Godot_v4.6.1/Godot_v4.6.1-stable_win64_console.exe --headless --path . --quit`
- If needed, use explicit project path:
  - `/mnt/c/Godot_v4.6.1/Godot_v4.6.1-stable_win64_console.exe --headless --path /mnt/d/04.GameWorkSpaces/00.GodotProjects/heroes-are-made --quit`
- Fallback command (Windows PowerShell via WSL; use when WSL direct launch fails with `socket failed 1`):
  - `powershell.exe -NoProfile -Command "& 'C:\Godot_v4.6.1\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\04.GameWorkSpaces\00.GodotProjects\heroes-are-made' --quit"`
- Fallback command for specific scene validation:
  - `powershell.exe -NoProfile -Command "& 'C:\Godot_v4.6.1\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\04.GameWorkSpaces\00.GodotProjects\heroes-are-made' --scene 'res://scenes/levels/level_02.tscn' --quit"`
- Record validation outcome in the response:
  - pass/fail
  - command used
  - key error line(s) if failed
- If CLI execution is blocked by known WSL limitation (`UtilBindVsockAnyPort ... socket failed 1`), do not skip silently:
  - report the 1st attempted WSL command and the blocking error
  - retry with the PowerShell fallback command above and report pass/fail
  - if both attempts fail, mark as `CLI validation blocked`
  - run and report alternative regression checks possible in current environment
  - keep the task marked as `CLI validation blocked` until executable environment is available

## Response Format (Mandatory)

When answering setup/change requests:

1. `Editor에서 먼저 할 일`
2. `그 다음 스크립트`

Do not invert this order.
- In script section, explain only the minimum trigger/feature code still required after editor setup.

## Language for Godot UI Terms (Mandatory)

- Assume Godot 4 Korean UI labels when explaining editor menus/settings.
- Prefer Korean menu paths first when giving editor instructions.
- If needed, English label can be added in parentheses for clarity.

## Game Concept (Current)

- Genre: Tower Defense
- Core loop:
  - Draw/recruit characters.
  - Equip characters with weapons.
  - Upgrade weapons.
  - Defeat enemies spawning from portals.

## TODO-Driven Workflow (Mandatory)

- All work must be tracked and driven through `TODO.md`.
- `TODO.md` is the active board for today's work and current-week focus.
- When the day ends (or before moving to next day), archive the day into a dated file under the current week folder.
- Weekly folder format: `docs/todo/YYYY-MM-Nw/` (month-based week index).
- Daily file format: `YYYY-MM-DD.md` inside that weekly folder.
- Next day starts again from `TODO.md` as the active board, while historical records remain in dated files.

### Required flow

1. Work from `TODO.md` during the day.
2. Roll over: move/save daily outcomes to `docs/todo/YYYY-MM-Nw/YYYY-MM-DD.md`.
3. Reset/update `TODO.md` for the new day and continue work from there.
4. When updating `TODO.md`, if completed sections from any previous date are still present, move them first to the matching daily archive file (`docs/todo/YYYY-MM-Nw/YYYY-MM-DD.md`) before adding new entries.

## Game Plan Sync (Mandatory)

- Whenever a gameplay/UI/system feature is newly implemented or behavior is changed, update `GAME_PLAN.md` in the same task.
- `GAME_PLAN.md` must reflect the latest implemented behavior (interaction rules, ownership/scope changes, and key formulas/tables).
- Treat `TODO.md` and `GAME_PLAN.md` updates as part of the definition of done for feature implementation.

## Godot Executable Path (Environment Note)

- Windows install path:
  - `C:\Godot_v4.6.1\Godot_v4.6.1-stable_win64.exe`
  - `C:\Godot_v4.6.1\Godot_v4.6.1-stable_win64_console.exe`
- WSL path mapping:
  - `/mnt/c/Godot_v4.6.1/Godot_v4.6.1-stable_win64.exe`
  - `/mnt/c/Godot_v4.6.1/Godot_v4.6.1-stable_win64_console.exe`
- Verified on `2026-02-22`: direct launch from current WSL session fails with
  `WSL ERROR: UtilBindVsockAnyPort ... socket failed 1`.
