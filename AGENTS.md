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
- Godot CLI validation is executed and result is recorded.

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
- Godot CLI validation executed and result recorded.
- `TODO.md` updated with review and validation outcome.

## Godot CLI Validation (Mandatory)

- After every code/scene change, run Godot CLI validation before completion.
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

## Godot Executable Path (Environment Note)

- Windows install path:
  - `C:\Godot_v4.6.1\Godot_v4.6.1-stable_win64.exe`
  - `C:\Godot_v4.6.1\Godot_v4.6.1-stable_win64_console.exe`
- WSL path mapping:
  - `/mnt/c/Godot_v4.6.1/Godot_v4.6.1-stable_win64.exe`
  - `/mnt/c/Godot_v4.6.1/Godot_v4.6.1-stable_win64_console.exe`
- Verified on `2026-02-22`: direct launch from current WSL session fails with
  `WSL ERROR: UtilBindVsockAnyPort ... socket failed 1`.
