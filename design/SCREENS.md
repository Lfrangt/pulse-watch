# Screens — Composition Specification

> Each screen lists: which components compose it, in what order, with what tokens.
> Reference React: `design/reference/screens.jsx`. SwiftUI port lives in `Shared/Views/Screens/`.
> No screen is "done" until it passes light/dark × zh/en × all 5 failure states (see COMPONENTS §Cross-cutting).

---

## Screen inventory

| ID  | Name              | Surface  | Reference fn         | Replaces                         |
|-----|-------------------|----------|----------------------|----------------------------------|
| S01 | Today             | iPhone   | `TodayScreen`        | `HomeView.swift` + `DashboardView.swift` |
| S02 | Vital Detail      | iPhone   | `VitalScreen`        | `HRVDetailView` / `HeartRateDetailView` / `BloodOxygenDetailView` / `SleepDetailView` / `StepsDetailView` / `StressDetailView` / `CaloriesDetailView` / `HealthAgeDetailView` |
| S03 | Workout Live      | iPhone   | `WorkoutScreen`      | `WorkoutView.swift`              |
| S04 | Sleep             | iPhone   | `SleepScreen`        | (folded into S02 sleep variant)  |
| S05 | History           | iPhone   | `HistoryScreen`      | `HistoryView.swift` + `WorkoutHistoryListView.swift` |
| S06 | Coach             | iPhone   | `CoachScreen`        | `CoachModeView.swift`            |
| S07 | Reports           | iPhone   | `ReportScreen`       | `WeeklyReportView` + `MonthlyReportView` |
| S08 | Settings          | iPhone   | (not in reference)   | `SettingsView.swift`             |
| S09 | Onboarding        | iPhone   | (not in reference)   | `OnboardingView.swift`           |
| W01 | Watch Home        | watchOS  | (manual port)        | `WatchHomeView.swift`            |
| W02 | Watch Workout     | watchOS  | (manual port)        | `WorkoutTrackingView.swift`      |
| W03 | Watch Plan        | watchOS  | (manual port)        | `TrainingPlanView.swift`         |
| X01 | Widget Small      | widget   | (manual port)        | `PulseWatchWidget.swift` family  |
| X02 | Widget Medium     | widget   | (manual port)        | "                                |
| X03 | Widget Large      | widget   | (manual port)        | "                                |
| X04 | Complication Circ | watchOS  | (manual port)        | `PulseComplication.swift`        |
| X05 | Complication Rect | watchOS  | (manual port)        | "                                |

---

## S01 · Today

**Edge padding.** `DS.Spacing.edge`.
**Vertical rhythm.** Sections separated by `DS.Spacing.group` (26pt). Inner card spacing `DS.Spacing.s` (8pt).

```
┌─ NAV (sticky)
│   left: MonoLabel "TODAY · MAY 5"
│   right: MonoLabel "EN/中"  + ⌥ icon
├─ HeroScore (P11)
│   ├ ScoreDial 240pt
│   ├ Insight (verb-first)
│   └ "30d trend" sparkline
├─ Card · 30d Score Chart (P9)
│   header: MonoLabel "SCORE · 30 DAYS" + mono "avg 78 · σ 8.2"
│   body:   ScoreChart
│   footer: first/last date in mono inkDim
├─ SectionHead "01 · Vitals · 6 metrics" + action "All"
├─ Grid 2-col, gap DS.Spacing.s
│   VitalChip × 6: HRV / RHR / Sleep / SpO₂ / Stress / Health Age
├─ SectionHead "02 · Train · suggested" + action "Start"
├─ Card · Suggested Workout
│   header row: title + reason mono + Chip(.accent "HEAVY")
│   exercise rows × 3 (separated by hairline lineSoft)
│   footer button: ink bg + "START WORKOUT" + "→"
├─ SectionHead "03 · Today · timeline"
└─ Timeline (P14): events from D.timeline
```

**Failure states.**
- No data: ScoreDial shows "—", insight shows "AWAITING DATA · 0/4 vitals", grid shows mono dashes.
- No HealthKit: replace HeroScore with permission CTA card; rest hidden.
- Demo: top sticky `Chip(.neutral "DEMO DATA")` above NAV.

---

## S02 · Vital Detail

**Variant:** parameterised by `metric: VitalMetric` (one of HRV/HR/RHR/SpO₂/Sleep/Steps/Stress/HealthAge).

```
┌─ NAV: ← back · MonoLabel <metric.label> · ⌥
├─ Hero
│   BigNum display3 + mono unit
│   MonoLabel "vs 30d baseline +6 ms"
├─ Card · TrendChart 7/30/90/6m/1y (P9 variant + range tabs)
├─ Card · Distribution histogram (mini)
├─ Card · Context norm
│   "Your range: 42–68 ms · Population p50–p90: 50–95 ms"
├─ Card · Today's range (min/max with timestamps)
└─ Card · "What this means" copy block
```

**Special: Sleep metric.** Replaces hero with `SleepBand` (P10) + duration BigNum + stage breakdown row.

---

## S03 · Workout Live

**Background.** Forced dark (wrist-style readability) regardless of system.
**Edge.** `DS.Spacing.edge`.

```
┌─ Top bar (mono): elapsed timer (display2) + workout type chip
├─ HRZoneRing (P13) centered, 240pt
├─ Stat row × 3: HR avg / Calories / Distance (BigNum title1 each)
├─ Section "Sets logged"
│   list rows: weight × reps · timestamp mono
├─ Bottom dock
│   primary: PAUSE (accent bg, accentInk text)
│   secondary: END (warn bg)
```

**HR pulse.** When workout active, accent dot in HR display pulses at real BPM rate. `Reduce Motion` → static fill.

---

## S05 · History

```
┌─ NAV: ← · "History" · filter chip group (mono)
├─ Filter strip: All · Chest · Back · Legs · Cardio · …
├─ Calendar (month grid) — each day:
│    • muted square if no workout
│    • accent square + muscle group letter if workout
├─ List: sessions chronological
│    row: date mono · type · duration mono · strain BigNum + 0–100 bar
└─ Empty: MonoLabel "NO SESSIONS YET"
```

---

## S06 · Coach

**Connection states drive top bar:**
- connected: `Chip(.good)` "online · 38ms"
- offline: `Chip(.neutral)` "offline · 12 queued"
- not configured: setup CTA card replaces conversation

```
┌─ Top bar: Coach · status chip
├─ Quick-prompt row: Chip × 4 horizontal scroll
├─ Conversation (chronological top-down)
│   user msg: right-aligned, bgSunk fill, ink text
│   agent msg: left-aligned, bgElev card, ink text
│   each: mono timestamp inkDim above
├─ Composer
│   text field bgElev, hairline
│   send button: accent bg
```

---

## S07 · Reports

Tabs at top: `WEEK · MONTH · YEAR`. Default `WEEK`.

```
┌─ Hero: avg score BigNum display2 + delta chip
├─ Card · Streak — current + best
├─ Card · Workouts — count + total duration + total volume
├─ Card · Sleep avg + consistency rating
├─ Card · Best/Worst day strip
├─ Card · Goals progress bars
├─ SectionHead "Achievements"
│   list of unlocked badges this period
├─ SectionHead "Anomalies"
│   compact list (P14 variant)
└─ SectionHead "Correlations"
   sentences in body text
```

---

## S08 · Settings

Plain list, sectioned. No card chrome — just rows separated by hairline.

```
Sections (in order):
  01 · Daily Brief — time, on/off
  02 · Notifications — anomaly toggles + thresholds
  03 · Goals — list + add (CRUD)
  04 · Locations — list + add (CRUD)
  05 · OpenClaw — gateway · token · agent · test · QR · LAN scan
  06 · Demo Mode — toggle
  07 · Data — export CSV/PDF/JSON · import JSON
  08 · App — icon picker · about · legal
```

Each row: left label `Body`, right value `MonoLabel inkMid` or chevron.

---

## S09 · Onboarding

Linear flow, full-screen cards, swipe (or button) to advance.

```
Step 1 · Welcome
   BigNum display2 "Pulse"
   body copy (verb-first, value prop)
Step 2 · HealthKit permission
   value prop + system permission CTA
Step 3 · Notification permission
   value prop + system permission CTA
Step 4 · OpenClaw (skippable)
   "Connect for AI coaching" + Setup / Skip buttons
Step 5 · Goal (skippable)
   one big stepper for daily steps target
Step 6 · Done
   "Open today" CTA
```

---

## W01 · Watch Home

```
┌─ Top: MonoLabel watch-label "TODAY"
├─ ScoreNumber (no dial) — DS.Typography.watchScore
├─ Status word (mono)
├─ Insight (1 line, body-s)
└─ Vital row × 3: HR · HRV · Sleep
```

Gestures (per DESIGN §8.2):
- swipe up → start workout (W02)
- swipe down → today's timeline
- long-press → suggested workout (W03)

---

## W02 · Watch Workout

```
┌─ Timer display2
├─ HR display3 + zone color dot
├─ Calories (mono small)
└─ Pause / End row at bottom
```

---

## W03 · Watch Plan

```
┌─ Group title (display3)
├─ Intensity chip
├─ 3 exercise rows: name · sets×reps mono
└─ START button (accent)
```

---

## X01–X03 · Widgets

| Size   | Composition |
|--------|-------------|
| Small  | Score (`widgetSScore`) + status mono label |
| Medium | Score (`widgetMScore`) + 3 vital rows (HR/HRV/sleep) |
| Large  | Score (`widgetLScore`) + insight + sleep band mini + suggestion summary |

All widgets: `DS.Spacing.widgetEdge`. No interaction; deep-link tap opens app.

---

## X04–X05 · Complications

| Family       | Content                |
|--------------|------------------------|
| Circular     | Score number only      |
| Rectangular  | Score + status mono    |

---

## Acceptance Per Screen

A screen passes review only if all of:
1. Renders identically in light + dark (per token semantics, not pixel-identical).
2. Renders without truncation in zh AND en, including longest-string fixtures.
3. All 5 failure states are explicitly designed (§COMPONENTS).
4. Passes `Scripts/check-design-rules.sh` (no token violations).
5. Reduce Motion is respected — every animated element has a static fallback.
6. VoiceOver labels exist for every meaningful interaction.
