---
name: task-plan-md
description: Create or update docs/tasks/<task-name>/plan.md for execution plans. Use when the user asks for plan/계획/실행계획, asks to break work into phases, or asks for checklist-driven implementation plans under docs/tasks (including typo docs/tastks).
---

# Task Plan MD

Create and maintain `docs/tasks/<task-name>/plan.md`.

## Workflow

1. Determine `<task-name>` in lowercase kebab-case.
- Prefer explicit user-provided slug.
- Normalize `docs/tastks` typo to `docs/tasks`.

2. Ensure related research link.
- If present, link `docs/tasks/<task-name>/research.md` at the top.

3. Create `plan.md` if missing.
- Use `scripts/create_plan_md.sh <task-name>`.
- If the file exists, update progress/checklist instead of replacing the whole file.

4. Keep execution structure explicit.
- 목표
- 범위 (In/Out)
- 단계별 작업 (Phase)
- 검증 체크리스트
- 리스크/대응
- 완료 선언 조건

5. Mark completion in the plan document.
- Add a clear completion status line with date.
- Convert checklist items to `[x]` when done.

## Planning Depth Standard

- Plan deeply, not at a high-level summary only.
- Break work into concrete phases, each with explicit deliverables and completion criteria.
- Include detailed sub-tasks that are directly executable and verifiable.
- Capture dependencies, ordering constraints, risks, fallback paths, and regression checks.
- Define measurable validation checkpoints for each major step.
- State assumptions and unresolved questions explicitly; add how to resolve them.
- Include exact file paths, target artifacts, and expected state changes whenever possible.

## Guardrails

- Keep plan content in `docs/tasks/<task-name>/plan.md` unless the user asks otherwise.
- Keep step descriptions concrete and testable.
