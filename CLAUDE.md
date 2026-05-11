# Pulse Watch — Claude Code Instructions

> Loaded automatically every session. Read top-to-bottom before any UI task.

---

## Project state: v2 Clinical UI redesign in progress

The app shipped v1 (build 202605051851) and is on hold in App Store Connect awaiting the v2 visual redesign.

**v2 is governed entirely by `design/`.** That folder is the design system constitution.

---

## Read these every UI session, in this order

1. `design/CLAUDE.md` ← per-design hard rules (mirror of design/RULES.md core)
2. `design/PLAN.md` ← which Phase you are on
3. `design/RULES.md` ← what is forbidden
4. `design/COMPONENTS.md` or `design/SCREENS.md` ← only the section for the file you're touching
5. `design/MAPPING.md` ← old → new file mapping; update its status when you complete a unit

`design/TOKENS.swift` is the source of truth for colors / spacing / radii / type. The same file is installed in the app at `Shared/Theme/DS.swift` (Phase 1).

---

## The cardinal rule of this redesign (R11)

**This redesign replaces UI only. Every functional behavior in the old view must continue to work in the new view, identically.**

Services, models, view-models, and algorithms are **not touched**. Every Phase 3 PR begins with a Screen Audit (`design/SCREEN_AUDIT_TEMPLATE.md`) catalogued from the OLD view, and the new view must satisfy every item before merge. A regression is a merge-blocker, not a follow-up.

## Hard rules (mirror of design/RULES.md — non-negotiable)

1. **Tokens.** No raw color hex, no numeric font size, no numeric padding/radius outside `Shared/Theme/DS.swift`. Use `DS.Color.<x>`, `DS.Spacing.<x>`, `DS.Radius.<x>`, `DS.Type.<x>`.
2. **One accent.** `DS.Color.accent` is the only saturated color. Status colors (`good`/`warn`/`bad`) are semantic, not decorative.
3. **Bilingual parity.** Every screen renders correctly in both `zh-Hans` and `en`. Hardcoded user-visible strings are forbidden — use `String(localized:)` or xcstrings keys.
4. **Action over information.** Every primary surface answers "what should I do?" Verb-first one-line `Insight` always visible.
5. **Three surfaces equal.** A change to iPhone that doesn't update Watch + Widget is incomplete.
6. **Reduce Motion non-optional.** All animations through `DS.Motion.respecting(_:reduce:)`.
7. **No drop shadows.** Depth comes from `bgElev` / `bgSunk` + hairline borders.
8. **No emoji as UI.** Strings, buttons, labels — no emoji.
9. **No skeleton loading.** Static `MonoLabel "loading…"` only.
10. **5 failure states required.** No-data, loading, error, stale, demo. Each component's preview must show all 5.
11. **Functional preservation (R11).** See above. Services / models / algorithms untouched. Audit before rewrite.

---

## Per-session protocol

1. Read `design/PLAN.md` — find current Phase + sub-task.
2. Read only the relevant `COMPONENTS.md` / `SCREENS.md` section.
3. Reference `design/reference/*.jsx` for behaviour, never copy styling.
4. Write code.
5. Run `./Scripts/check-design-rules.sh` — must return 0.
6. Build for relevant target — must compile.
7. Visual check — both light + dark, both zh + en, all 5 failure states.
8. Commit. Update the row in `design/MAPPING.md` (`pending` → `done`).

**One sub-task per session is the right pace.** Previous attempt failed by batching. Resist.

---

## When you find ambiguity

Stop and ask. Do not improvise. The user reviews open questions; you do not silently resolve them.
List ambiguities in PR description under `## Open questions`.

---

## What you must NOT touch in this redesign

- `Shared/Services/*` — services are unchanged.
- `Shared/Models/*` — models / SwiftData schemas are unchanged.
- `*/ViewModels/*` — view-models are unchanged.
- `Localizable.xcstrings` keys that exist — values can change, keys do not.
- The algorithms in `design/DESIGN.md` §5 (score, stress, strain, sleep, 1RM, zones, correlation, KDM). You may change *how* they are presented; you must not change *what* they compute.

If a redesign requires extending a service or adding a model field, **stop and surface it** — do not silently extend services. That is a product decision, not a design decision.

---

## Existing reference

For functional understanding (what the app does, not how it looks): `FUNCTIONAL_SPEC.md` in project root.

For pre-redesign UI state (do not copy styling): existing files in `PulseWatch/Views/`. Read for behaviour and HealthKit hookup; do not transliterate the visuals.

---

## Failure modes from previous attempt (do not repeat)

- Batching multiple screens in one PR → 15 screens, 90 issues, no clean ground truth. **One screen per PR.**
- Hardcoding colors/sizes "just for this one place" → drift everywhere within days. **Tokens or fail.**
- Skipping failure states ("happy path is enough") → ship breaks for new users on day one. **All 5 states or component is not done.**
- Skipping bilingual check ("we'll fix Chinese later") → Chinese always has truncation no one notices. **Both languages every PR.**
- Skipping reduce-motion → a11y review fails late. **DS.Motion.respecting() always.**

These were the actual leaks. The rules above exist to close them.
