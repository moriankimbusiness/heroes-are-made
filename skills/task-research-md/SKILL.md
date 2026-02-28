---
name: task-research-md
description: Create or update docs/tasks/<task-name>/research.md for repository research requests. Use when the user asks for research/리서치/조사, asks to investigate a topic, or asks to write findings under docs/tasks (including typo docs/tastks).
---

# Task Research MD

Create and maintain `docs/tasks/<task-name>/research.md`.

## Workflow

1. Determine `<task-name>` in lowercase kebab-case.
- Prefer an explicit user-provided slug.
- If the user gives a typo path like `docs/tastks`, normalize to `docs/tasks`.

2. Create the task directory if missing.
- Target path: `docs/tasks/<task-name>/`

3. Create `research.md` if missing.
- Use `scripts/create_research_md.sh <task-name>`.
- If the file already exists, append/update sections instead of blind overwrite.

4. Keep structure actionable.
- `목적`
- `범위`
- `조사 방법`
- `사실 근거`
- `리스크/가정`
- `결론`
- `출처`

5. Keep language aligned with the user's request.
- Default to Korean when the user is writing in Korean.

## Research Depth Standard

- Always investigate deeply, not superficially.
- Cover concrete details, edge cases, assumptions, and tradeoffs.
- Prefer primary evidence and cite exact sources for each key claim.
- Include specific numbers, dates, file paths, and scope boundaries when available.
- Validate consistency across sources; if sources conflict, document the conflict and resolution.
- Explicitly list what is known, what is inferred, and what remains uncertain.
- Do not end at a summary; provide actionable findings and follow-up checks.

## Guardrails

- Write research content only in `docs/tasks/<task-name>/research.md` unless the user requests additional files.
- Preserve existing validated notes; add dated updates when revising.
