# PLAN — Fast Track

> **Goal: every session ends with the user seeing real UI change.**
> Primitives are built just-in-time per screen, not upfront. No bikeshedding.
>
> Cardinal rule (R11): functional behavior 100% preserved. Services / models / view-models / algorithms — untouched.

---

## Phase 0 — Scaffolding ✓ done

`design/` package + `Scripts/check-design-rules.sh` + project `CLAUDE.md` + reference jsx — all in place.

---

## Phase 1 — Install DS (additive only) · ~30 min · 1 session

**Goal.** `DS.swift` exists in 3 targets, builds clean. Nothing else changes.

```
1. cp design/TOKENS.swift Shared/Theme/DS.swift
2. Add to PulseWatch + PulseWatchWatch + PulseWatchWidget targets
3. xcodegen generate (if needed)
4. xcodebuild × 3 schemes — 0 warning
5. git commit -m "Phase 1 — install DS design tokens (additive)"
```

**Gate.** All 3 targets build. `Shared/Theme/PulseTheme.swift` UNTOUCHED. View files UNTOUCHED. Commit hash reported.

**Do not.** Edit COMPONENTS.md / SCREENS.md / RULES.md during this phase. If `DS.swift` won't compile, fix `DS.swift` (it is the source of truth). Renames propagate to docs in a follow-up cleanup, not now.

---

## Phase 2 — Rebuild iPhone screens, JIT primitives · 1 session per screen

Each session = one screen rebuilt + all primitives that screen needs + all old files for that screen deleted. **The user sees the new UI in app at end of session.**

### Per-session protocol

1. **Read** `design/CLAUDE.md`, `design/RULES.md` R11, `design/SCREEN_AUDIT_TEMPLATE.md`.
2. **Audit** the OLD view (template §1–7, copy into PR description).
3. **Identify primitives needed** for this screen by reading `design/SCREENS.md` entry. Cross-reference with what already exists in `Shared/Theme/Components/`.
4. **Build missing primitives** in `Shared/Theme/Components/` (one file each, with `#Preview` covering all 5 failure states + light/dark + zh/en). Reference `design/COMPONENTS.md` spec.
5. **Write the new screen** in `Shared/Views/Screens/v2/<Name>.swift` (or per-platform path). Use only DS + primitives. No PulseTheme references.
6. **Carry over data hookup** from audit §1 — every `@State`, `@Query`, service call, lifecycle hook.
7. **Update routing** — replace old view with new in NavigationStack / tab / sheet host.
8. **Delete old view file(s).** Verify `rg "OldViewName" PulseWatch PulseWatchWatch PulseWatchWidget Shared` returns empty.
9. **Verify gate** (below).
10. **Commit** + update `design/MAPPING.md` status `pending → done`.

### Order (do strictly)

| # | Screen | Primitives this screen introduces | Replaces |
|---|--------|-----------------------------------|----------|
| 1 | **S01 Today** | MonoLabel, BigNum, Card, SectionHead, Chip, ScoreDial, Sparkline, ScoreChart, VitalChip, HeroScore, TrendArrow, Insight, Timeline | HomeView, DashboardView |
| 2 | **S02 Vital Detail** | (parameterised — reuses S01 primitives + adds histogram) | 8 detail views (HRV, HR, RHR, SpO₂, Sleep band uses SleepBand, Steps, Stress, HealthAge) |
| 3 | **S05 History** | (calendar grid; reuses chips + SectionHead) | HistoryView, WorkoutHistoryListView |
| 4 | **S07 Reports** | (reuses everything) | WeeklyReportView, MonthlyReportView, AnomalyTimelineView, CorrelationInsightsView |
| 5 | **S03 Workout Live** | HRZoneRing | WorkoutView, ManualWorkoutView |
| 6 | **S06 Coach** | (chat composer — small) | CoachModeView |
| 7 | **S08 Settings** | (mostly mechanical) | SettingsView |
| 8 | **S09 Onboarding** | (linear flow) | OnboardingView |

S01 is the longest session (most primitives are written for the first time). S02–S08 reuse heavily.

### Gate per screen

- [ ] Audit checklist (§1–7) filled in PR description, every item.
- [ ] Every audit item confirmed working in new view (simulator walkthrough).
- [ ] Old view files deleted; `rg` returns empty.
- [ ] All new primitives have `#Preview` covering 5 failure states × light/dark × zh/en.
- [ ] `./Scripts/check-design-rules.sh <changed files>` → 0.
- [ ] iOS + watchOS + Widget targets build, 0 warnings.
- [ ] Bilingual screenshot pair (zh × en) attached.
- [ ] Light + dark screenshot pair attached.
- [ ] `design/MAPPING.md` updated.

### Anti-patterns (don't repeat)

- Building primitives upfront before any screen — over-engineering, no visible progress.
- Batching multiple screens in one PR.
- Touching services / models / view-models — that is a product decision, surface to user.
- Skipping audit — "I can see the features" misses long-press, haptics, deep-links.

---

## Phase 3 — Watch app · 1 session per screen

After all iPhone screens done.

| # | Screen | Replaces |
|---|--------|----------|
| 1 | W01 Watch Home | WatchHomeView, SummaryView |
| 2 | W03 Watch Plan | TrainingPlanView |
| 3 | W02 Watch Workout | WorkoutTrackingView |

Same protocol. Same gates. Outdoor-readability check on Watch sim required.

---

## Phase 4 — Widgets + Complications · 1 session

5 surfaces: small / medium / large widgets + circular / rectangular complications. Tight, batchable since each is small.

**Gate.** Tested on home screen + lock screen StandBy + watch faces (Modular, Infograph).

---

## Phase 5 — Cleanup · 0.5 session

- `rg PulseTheme PulseWatch PulseWatchWatch PulseWatchWidget Shared` → expect empty.
- Delete `Shared/Theme/PulseTheme.swift`.
- Audit `Localizable.xcstrings` for orphan keys.
- Final `check-design-rules.sh` full scan → 0.
- Bump app version, update CHANGELOG.

---

## Time map (realistic)

| Phase | Effort         | What user sees |
|-------|----------------|----------------|
| 1     | 30 min         | App unchanged. DS installed. |
| 2 × 8 | 1 session/screen | After S01: new Today screen live. After S08: full iPhone redone. |
| 3 × 3 | 1 session/screen | New Watch app live. |
| 4     | 1 session      | New widgets + complications. |
| 5     | 30 min         | Old code purged. |

**Total: ~13 sessions.** First visible UI change in session 2 (Phase 1 → Phase 2-S01).

---

## When in doubt

Stop and surface to user. Don't improvise. Don't extend services. Don't batch.
