# Pulse — Design Package

This folder is the **constitution** for Pulse v2 UI. Source of truth for everything visual.

## Files

| File | Role |
|------|------|
| `DESIGN.md`     | Original design doc from Claude Design (v1.0 · 2026-05-05). Tokens, mood, rules. |
| `TOKENS.swift`  | Swift port of color/spacing/type tokens. Drop-in to `Shared/Theme/DS.swift`. |
| `COMPONENTS.md` | Spec for 15 SwiftUI primitives. Each maps to `primitives.jsx`. |
| `SCREENS.md`    | Spec for every screen (iPhone + Watch + Widget). Maps to `screens.jsx`. |
| `MAPPING.md`    | Old Swift file → new design ownership. Status tracked here. |
| `RULES.md`      | Hard rules + grep-able forbidden patterns. |
| `PLAN.md`       | Phase order. Read first every session. |
| `reference/`    | Original React design (read-only — do not copy styling). |

## Workflow

1. Read `PLAN.md` — find current phase.
2. Read the relevant section of `COMPONENTS.md` or `SCREENS.md`.
3. Reference `reference/*.jsx` for behavior. Use `TOKENS.swift` for styling.
4. Run `../Scripts/check-design-rules.sh` before committing.
5. Update `MAPPING.md` status from `pending` → `done`.

The full per-session protocol is in `../CLAUDE.md` (project root, auto-loaded by Claude Code).

## Versioning

Bump DESIGN.md version (currently `1.0`) when a hard rule changes. Component spec changes can be inline-noted with a `**Changed YYYY-MM-DD**:` line.
