# Godot Performance Checklist

## 1) Frame Loop Use
- [ ] `_process` / `_physics_process` is truly necessary.
- [ ] Event/signal-based update was considered first.
- [ ] No UI-only logic running every frame without need.

## 2) Runtime Cost in Hot Paths
- [ ] No repeated `get_node*` lookups in per-frame callbacks.
- [ ] No resource loads in per-frame callbacks.
- [ ] No avoidable allocations/rebuilds in tight loops.

## 3) State Design
- [ ] Base state and debug/override state are separated.
- [ ] Final state is resolved in one place (single apply function).
- [ ] Signal flow is clear and avoids duplicate connections.

## 4) Scene/Editor Authority
- [ ] Inspector-authored values remain source of truth.
- [ ] Script only handles trigger/feature runtime behavior.
- [ ] No unintended runtime override of editor-authored animation/UI settings.

## 5) Validation
- [ ] Godot CLI headless validation executed.
- [ ] If blocked (WSL issue), blocking error recorded and alternative checks documented.
- [ ] Regression points documented (what was manually verified).

## 6) Review Log (fill per task)
- Date:
- Scope:
- Hot path decision (`_process` used? why?):
- Signal/event conversion applied:
- CLI result:
- Regression checks:
