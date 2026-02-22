# Agent Working Rules (Project-Specific)

## Godot Workflow Priority (Mandatory)

For any Godot scene/gameplay setup request, follow this order strictly:

1. **Editor-first instructions**
   - Explain what to set in the Godot editor first (node selection, Inspector values, scene tree actions, save step).
   - These editor steps must be provided before any script guidance.

2. **Script-second instructions**
   - After editor steps, explain only the script part that is still needed.
   - Script must not override editor-authored values unless the user explicitly asks for runtime override behavior.

## Response Format (Mandatory)

When answering setup/change requests:

1. `Editor에서 먼저 할 일`
2. `그 다음 스크립트`

Do not invert this order.

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
