# PLAN — Phased Migration

> Strict order. Each phase is a single concentrated commit (or small commit series). Do not start phase N+1 until phase N's acceptance gate passes.
>
> The cardinal sin of UI refactors is doing too much in one go. We will resist.

---

## Phase 0 · Scaffolding (already done by this scaffold)

- [x] `design/` package created with DESIGN, COMPONENTS, SCREENS, MAPPING, RULES, PLAN, TOKENS.swift
- [x] `Scripts/check-design-rules.sh` written
- [x] Project-level `CLAUDE.md` written
- [x] Reference React files copied to `design/reference/` (read-only)

**Gate.** None — this exists.

---

## Phase 1 · Install tokens (additive only)

**Goal.** `DS.swift` exists in the project and is buildable. **Nothing else changes.**

`PulseTheme.swift` is **not** touched. Old views keep referencing it and keep working unchanged. This is intentional: the rebuild happens in Phase 3, one screen at a time. PulseTheme dies naturally when the last old view is deleted (Phase 6 cleanup).

**Steps.**
1. Copy `design/TOKENS.swift` → `Shared/Theme/DS.swift`.
2. Add the file to Xcode project: PulseWatch + PulseWatchWatch + PulseWatchWidget targets.
3. `xcodegen generate` if needed.
4. Build all 3 targets — should compile cleanly. DS is currently unused.
5. Commit.

**Gate.**
- App compiles for iOS + watchOS + Widget targets, 0 new warnings.
- `Shared/Theme/DS.swift` exists and is in all 3 targets.
- `Shared/Theme/PulseTheme.swift` is **untouched**.
- No view files are touched.
- Commit message: `Phase 1 — install DS design tokens (additive)`

---

## Phase 2 · Build primitives

**Goal.** Implement P1–P15 from `COMPONENTS.md` as standalone SwiftUI views with `#Preview` covering all states.

**Order.** P1 → P2 → P3 → P4 → P5 → P6 → P15 → P12 → P14 → P10 → P13 → P9 → P11 → P8 → P7

(Reason: simpler primitives first; composite primitives last.)

**Layout.** `Shared/Theme/Components/`. One file per component:
```
Shared/Theme/Components/
├── MonoLabel.swift
├── BigNum.swift
├── TrendArrow.swift
├── Sparkline.swift
├── SectionHead.swift
├── Card.swift
├── Chip.swift
├── Insight.swift
├── Timeline.swift
├── SleepBand.swift
├── HRZoneRing.swift
├── ScoreChart.swift
├── HeroScore.swift
├── VitalChip.swift
└── ScoreDial.swift
```

**Each file's preview** must show: default, no-data, loading, error, demo, both light + dark, both zh + en.

**Gate.**
- All 15 components compile.
- All previews render.
- `check-design-rules.sh` returns 0.
- Spot-screenshot 3 components in zh + en, attach to PR.

---

## Phase 3 · iPhone screens — rebuild one at a time

**This is the actual redesign.** Each screen is rewritten from zero using DS tokens + the Phase 2 primitives. The old view file is deleted; nothing of its visual structure is carried over.

**The cardinal constraint (R11):** functional behavior is 100% preserved. Services, models, and view-models are not touched. The audit step below makes preservation auditable.

### Per-screen protocol (every Phase 3 PR)

1. **Audit the old view.** Open `design/SCREEN_AUDIT_TEMPLATE.md`, copy into PR description, fill in every section by reading the OLD view file end-to-end. Catalog every data dep, interaction, navigation, state, side effect, lifecycle hook.
2. **Read the design.** `design/SCREENS.md` entry for this screen + relevant `design/COMPONENTS.md` primitives only. Don't read any reference jsx for styling — only behavior.
3. **Write the new view from zero.** Place at `Shared/Views/Screens/v2/<Name>.swift` (or per-platform equivalent). Use only DS + primitives. No PulseTheme references in the new file.
4. **Carry over data hookup.** All `@State` / `@Query` / service calls / lifecycle from the old view's audit must reappear in the new view.
5. **Update routing.** Whatever pushed/presented the old view now points to the new view.
6. **Delete old file(s).** Verify with `rg "OldViewName"` returns empty.
7. **Verify acceptance gate (below).**
8. **Update `design/MAPPING.md`** — flip the row's status to `done`.

### Order (priority)

1. **S01 Today** — sets the tone for everything else.
2. **S02 Vital Detail** — parameterized; once done, 8 metrics are unblocked.
3. **S05 History** — simpler, builds confidence.
4. **S07 Reports** — exercises many primitives.
5. **S03 Workout Live** — special case (forced dark, real-time HR pulse).
6. **S06 Coach** — connection states + threading.
7. **S08 Settings** — long but mechanical.
8. **S09 Onboarding** — last; depends on others to deep-link into.

### Acceptance gate per screen

- [ ] Screen audit checklist (template §1–7) is filled in PR description, every item.
- [ ] Every audit item has been confirmed working in the new view (manual simulator walkthrough).
- [ ] Old view file deleted; no references remain (`rg` empty).
- [ ] `MAPPING.md` row status: `done`.
- [ ] `./Scripts/check-design-rules.sh <changed files>` returns 0.
- [ ] Builds for iOS + watchOS + Widget, 0 warnings.
- [ ] Bilingual screenshot pair (zh × en) attached.
- [ ] Light + dark screenshot pair attached.
- [ ] All 12 state variants from audit §4 verified.

### Anti-pattern (do not repeat)

- Batching multiple screens in one PR.
- Rewriting a service "while we're here".
- Skipping the audit because "I can see all the features in the file" — features get missed; the audit makes them explicit.
- Adding a new ViewModel field because the new design "needs" it. That is a product decision; surface to user.

---

## Phase 4 · Watch app

**Steps.**
1. W01 Watch Home — replaces `WatchHomeView` + `SummaryView`.
2. W03 Watch Plan — replaces `TrainingPlanView`.
3. W02 Watch Workout — replaces `WorkoutTrackingView`. Most complex, save for last in this phase.

**Gate.** Each screen tested on Watch simulator (Series 10 + SE) for both light + dark. Outdoor-readability check: Watch face brightness max, ambient lit room, score number is readable at arm's length.

---

## Phase 5 · Widgets + Complications

**Steps.**
1. X01 Widget Small
2. X02 Widget Medium
3. X03 Widget Large
4. X04 Complication Circular
5. X05 Complication Rectangular

**Gate.** Each tested on iPhone home screen (small + medium + large + lock-screen StandBy). Each complication tested on watch face (Modular, Infograph, Reflections).

---

## Phase 6 · Cleanup

- Delete any view files marked `pending` in `MAPPING.md` that ended up unused.
- Audit `Localizable.xcstrings` for orphan keys (key has no occurrence in code).
- Run `check-design-rules.sh` once more — should be a no-op.
- Bump app version, update CHANGELOG.

**Gate.** App ships.

---

## Time estimate (rough, optimistic)

| Phase | Effort         | Notes |
|-------|----------------|-------|
| 1     | 1 session      | Token swap is mechanical |
| 2     | 2–3 sessions   | 15 primitives w/ previews |
| 3     | 1 session/screen × 8 = 8 sessions | Be patient |
| 4     | 2 sessions     | Watch is fiddly |
| 5     | 2 sessions     | Widgets + complications |
| 6     | 0.5 session    | Cleanup |

Total: ~15–17 sessions. **One screen per session is the right pace.** Resist the urge to batch.

---

## Per-session protocol (read this every session)

1. Read `design/CLAUDE.md` (auto-loaded if at project root).
2. Identify the current Phase + sub-task from this file.
3. Read the relevant section of `COMPONENTS.md` or `SCREENS.md` only for the file you're touching.
4. Write code. Reference `design/reference/*.jsx` for behaviour, never copy styling.
5. `./Scripts/check-design-rules.sh` — must pass.
6. Build for relevant target. Must compile.
7. Visual check: open preview / simulator. Both light + dark, both zh + en. Each failure state.
8. Commit. Update `MAPPING.md` status.

If at any step you find ambiguity in the design, **stop and surface it** — do not improvise. The user reviews open questions; you do not silently resolve them.
