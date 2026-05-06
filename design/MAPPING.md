# File Mapping — Old → New

> Concrete mapping from existing Swift files to new design ownership.
> Updated as Phase 4 progresses; `status` column tracks completion.
>
> **Status legend:** `pending` | `in-progress` | `done` | `deleted` | `kept-as-is`

---

## Theme

| Old file                        | Action                | New                                  | Status   |
|---------------------------------|-----------------------|--------------------------------------|----------|
| `Shared/Theme/PulseTheme.swift` | DELETE in Phase 5 cleanup (after all v2 screens shipped) | `Shared/Theme/DS.swift` (from `design/TOKENS.swift`) | pending  |

---

## Components (replace wholesale, do not migrate state)

| Old (Views/Components/)              | Action  | New primitive | Status |
|--------------------------------------|---------|---------------|--------|
| `StatusCard.swift`                   | DELETE  | merged into S01 hero composition | pending |
| `SuggestionCard.swift`               | DELETE  | merged into S01 suggestion card  | pending |
| `RecoveryTimelineView.swift`         | REPLACE | `Timeline` (P14) + builder kept  | pending |
| `ReadinessSparkline.swift`           | REPLACE | `Sparkline` (P4)                 | pending |
| `WeeklyReadinessChart.swift`         | REPLACE | `ScoreChart` (P9)                | pending |
| `WeeklyTrendChartsView.swift`        | REPLACE | `ScoreChart` variants            | pending |
| `TrendCard.swift`                    | REPLACE | `Card` + `ScoreChart`            | pending |
| `VitalsGrid.swift`                   | REPLACE | grid of `VitalChip` (P8) in S01  | pending |
| `SleepBandCard.swift`                | REPLACE | `SleepBand` (P10)                | pending |
| `GoalProgressCard.swift`             | KEEP-MIGRATE | port to `Card` + token bars | pending |
| `PeriodSummaryCard.swift`            | REPLACE | `Card` + `BigNum` rows           | pending |
| `MuscleInsightsCard.swift` (Services dir, but is a card) | KEEP-MIGRATE | port to tokens | pending |
| `EmptyStateView.swift`               | REPLACE | per-screen mono "AWAITING DATA" | pending |
| `LaunchScreenView.swift`             | KEEP    | rebuild with tokens              | pending |
| `AppIconView.swift`                  | KEEP    | retire hardcoded gradient, use accent token | pending |
| `ShareCardView.swift`                | KEEP-MIGRATE | re-tokenize                  | pending |
| `HealthSnapshotShareCard.swift`      | KEEP-MIGRATE | re-tokenize                  | pending |
| `InteractiveChartOverlay.swift`      | KEEP    | overlay logic kept; tokens swap   | pending |
| `QRScannerView.swift`                | KEEP    | functional view; tokens swap     | pending |
| `GymSearchView.swift`                | KEEP    | tokens swap                      | pending |

---

## Screens

| Old (Views/Screens/)              | Action  | New screen        | Status |
|-----------------------------------|---------|-------------------|--------|
| `HomeView.swift`                  | REPLACE | S01 Today         | done    |
| `DashboardView.swift`             | DELETE  | folded into S01   | done    |
| `HistoryView.swift`               | REPLACE | S05 History       | pending |
| `WorkoutHistoryListView.swift`    | DELETE  | folded into S05   | pending |
| `WorkoutHistoryDetailView.swift`  | REPLACE | S05 detail variant| pending |
| `WorkoutView.swift`               | REPLACE | S03 Workout Live  | pending |
| `ManualWorkoutView.swift`         | REPLACE | S03 manual variant| pending |
| `WorkoutShareScreen.swift`        | KEEP-MIGRATE | re-tokenize  | pending |
| `HRVDetailView.swift`             | REPLACE | S02 metric=hrv    | done    |
| `HeartRateDetailView.swift`       | REPLACE | S02 metric=hr     | done    |
| `BloodOxygenDetailView.swift`     | REPLACE | S02 metric=spo2   | done    |
| `SleepDetailView.swift`           | REPLACE | S02 metric=sleep  | done    |
| `StepsDetailView.swift`           | REPLACE | S02 metric=steps  | done    |
| `StressDetailView.swift`          | REPLACE | S02 metric=stress | done    |
| `CaloriesDetailView.swift`        | REPLACE | S02 metric=cal    | done    |
| `HealthAgeDetailView.swift`       | REPLACE | S02 metric=age    | done    |
| `ActivityDetailView.swift`        | REPLACE | S02 metric=activity | done    |
| `AnomalyTimelineView.swift`       | REPLACE | folded into S07   | pending |
| `CorrelationInsightsView.swift`   | REPLACE | folded into S07   | pending |
| `WeeklyReportView.swift`          | REPLACE | S07 Reports week  | pending |
| `MonthlyReportView.swift`         | REPLACE | S07 Reports month | pending |
| `CoachModeView.swift`             | REPLACE | S06 Coach         | pending |
| `SettingsView.swift`              | REPLACE | S08 Settings      | pending |
| `OnboardingView.swift`            | REPLACE | S09 Onboarding    | pending |
| `GoalSettingView.swift`           | KEEP-MIGRATE | re-tokenize within S08 | pending |
| `NutritionView.swift`             | KEEP-MIGRATE | re-tokenize  | pending |
| `ChallengeView.swift`             | KEEP-MIGRATE | re-tokenize  | pending |
| `StrengthView.swift`              | KEEP-MIGRATE | re-tokenize  | pending |
| `TrainingCalendarView.swift`      | DELETE  | folded into S05   | pending |
| `GymArrivalFlowView.swift`        | KEEP-MIGRATE | re-tokenize  | pending |
| `DemoDataProvider.swift`          | KEEP-AS-IS | service, no UI    | kept-as-is |

---

## Watch app

| Old                                       | Action  | New             | Status |
|-------------------------------------------|---------|-----------------|--------|
| `PulseWatchWatch/Views/WatchHomeView.swift`     | REPLACE | W01 Watch Home  | pending |
| `PulseWatchWatch/Views/SummaryView.swift`       | DELETE  | folded into W01 | pending |
| `PulseWatchWatch/Views/WorkoutTrackingView.swift`| REPLACE | W02 Watch Workout | pending |
| `PulseWatchWatch/Views/TrainingPlanView.swift`  | REPLACE | W03 Watch Plan  | pending |
| `PulseWatchWatch/Views/GymArrivalView.swift`    | KEEP-MIGRATE | re-tokenize | pending |
| `PulseWatchWatch/Complications/PulseComplication.swift` | REPLACE | X04+X05 | pending |

---

## Widgets

| Old                                     | Action  | New                | Status |
|-----------------------------------------|---------|--------------------|--------|
| `PulseWatchWidget/PulseWatchWidget.swift` | REPLACE | X01+X02+X03      | pending |

---

## Services / Models / View Models

**KEEP ALL.** No service/model/view-model is touched in this redesign. Specifically:
- `Shared/Services/*` — kept verbatim. UI views consume them as before.
- `Shared/Models/*` — kept verbatim. SwiftData migrations stay.
- `PulseWatch/Services/*` — kept verbatim.
- `PulseWatchWatch/Services/*` — kept verbatim.

If a redesign requires a new view-model field, that is a flag — discuss with user first; do NOT silently extend services.

---

## Assets

- `Assets.xcassets/` — color set entries become token-driven; existing image assets (logos, demo data) kept.
- App icons (`generated_icon_*.png`, `icon_v4_*.png`) — keep, they're picker variants for F6.

---

## Localizable.xcstrings

KEEP. No string keys removed. New strings get added with both `zh-Hans` and `en` values; en pseudo-translation acceptable as placeholder during build, but PR cannot land without real zh.
