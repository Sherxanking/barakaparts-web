# Project Operating Rules (Antigravity)

## Goal
Build a simple, reliable, professional Flutter app (production-quality).

## Non-negotiables
- Small diffs only. One small task at a time.
- Touch max 1–3 files per task.
- No refactors, renames, folder moves unless explicitly requested.
- Do not delete code unless explicitly requested.
- Preserve behavior; focus on compiling + safe incremental improvements.

## Workflow (required)
1) Write a short plan (3–7 bullets).
2) State which files will be edited.
3) Apply patch/diff.
4) Provide manual test steps.
5) Provide risk + rollback steps (git restore . / revert).

## Build-fix protocol
- Fix only the FIRST error from build logs.
- After each fix: run/build and commit.

## UI/UX checklist
- Spacing system: 8/16/24/32.
- Clear typography hierarchy.
- Loading/Empty/Error states on every screen.
- Tap targets >= 44px.