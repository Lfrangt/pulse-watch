# Components — Specification

> Each primitive below maps 1:1 to a SwiftUI `View` to be implemented in `Shared/Theme/Components/`.
> The reference implementation in React lives at `design/reference/primitives.jsx` — read it for behaviour, do not transliterate the styling (use `DS` tokens).
> Every component must support light + dark, and zh + en, with no truncation in any combination.

---

## Conventions

- All colors via `DS.Color.*`. Never hex.
- All numerics (size, padding, radius, stroke) via `DS.Spacing.*`, `DS.Radius.*`, `DS.Stroke.*`. Never literals.
- All fonts via `DS.Typography.*`. Never `.system(size: <n>)`.
- Mono LABEL strings: English uppercase + tracking, Chinese plain. Use `.dsMonoLabel(chinese: lang == .zh)`.
- Numbers in any "measurement" context use `.monospacedDigit()` (already baked into `DS.Typography.display*`).
- Reduce Motion respected through `DS.Motion.respecting(_:reduce:)`.

---

## P1 · `MonoLabel`

**Job.** Render a small uppercase tracked label in JetBrains-Mono-like style. The "this is metadata, not content" signal.

**Inputs.** `text: String` · `size: MonoSize = .m` · `chinese: Bool` · `color: Color? = nil`

**Defaults.** `font: DS.Typography.mono` · `color: DS.Color.inkMid`

**States.**
- default — `inkMid`
- emphasised — `ink`
- dim — `inkDim`
- accent — `accent` (only on accent-bg surfaces; flag in usage)

**Bilingual.** zh skips `.textCase(.uppercase)` and zeroes tracking.

**Forbidden.** Body text in mono. Mono in titles. Mono on score numbers (those are display, not labels).

---

## P2 · `BigNum`

**Job.** Render a measured number with optional unit. Tabular figures, light weight, tight tracking.

**Inputs.** `value: String` · `unit: String? = nil` · `size: BigNumSize` · `color: Color? = DS.Color.ink`

**Sizes.** `.display1` (96, score) · `.display2` (72, timer) · `.display3` (48, vital hero) · `.title1` (28, vital chip)

**Layout.** Number and unit share a baseline. Unit font is `DS.Typography.mono` and ~18% of the number size. Gap between them: `DS.Spacing.xs`.

**Variants.**
- inline — number + unit horizontal
- stacked — number with mono unit below (right-aligned)

**Forbidden.** Animations on values that move <1 unit. Unit at the same font size as the number. Decimals as `·`.

---

## P3 · `TrendArrow`

**Job.** 9×9pt direction indicator.

**Inputs.** `direction: TrendDirection` (`.up | .down | .flat`) · `polarity: Polarity = .higherIsBetter`

**Color rules.** Polarity-aware:
- `.higherIsBetter` (HRV, sleep): up = `good`, down = `bad`, flat = `inkDim`
- `.lowerIsBetter` (RHR, stress): down = `good`, up = `bad`
- `.contextual` (SpO₂): caller supplies color; default `inkDim`

**Forbidden.** Mechanical "up = green, down = red" without polarity awareness.

---

## P4 · `Sparkline`

**Job.** Tiny inline trend line.

**Inputs.** `data: [Double]` · `width: CGFloat = 120` · `height: CGFloat = 32` · `color: Color = DS.Color.ink` · `fill: Bool = false`

**Composition.** Path with `DS.Stroke.chartLine` + `.round` linecap; terminal dot `r=2` filled with line color; optional area fill at `0.15` opacity.

**Forbidden.** Grid lines. Axis labels. Multi-color line. Animated draw (use static).

---

## P5 · `SectionHead`

**Job.** Editorial section divider with mono number prefix.

**Inputs.** `num: String` (e.g. `"01"`) · `title: String` (localized) · `sub: String? = nil` · `action: String? = nil` · `chinese: Bool`

**Layout.** Horizontal flex. Left: mono num at `inkDim` + 10pt gap + title `DS.Typography.bodyS .medium` + optional mono sub. Right (optional): action label in mono accent.

**Numbering.** Restart from `01` per screen. Don't carry across screens.

---

## P6 · `Card`

**Job.** Information container.

**Inputs.** `padding: CGFloat = DS.Spacing.l` · `sunk: Bool = false` · `@ViewBuilder content: () -> Content`

**Surface.** `sunk ? DS.Color.bgSunk : DS.Color.bgElev` · `DS.Radius.card` · hairline border `DS.Color.line`.

**Forbidden.** Drop shadows. Inner gradients. Margin (callers control external spacing).

---

## P7 · `ScoreDial`

**Job.** Visualise 0–100 score on a 240pt dial with tick marks.

**Inputs.** `score: Int` · `status: String` (localized) · `size: CGFloat = 240` · `animated: Bool = true` (respects Reduce Motion)

**Composition.**
- 60 tick marks around the perimeter — 12 major (`tickMajor`), 48 minor (`tickMinor`)
- Accent arc: from −90° baseline, length `score / 100 × 360°`, stroke `chartHeavy`, color `accent`, linecap round
- Center: BigNum `display1` for score, mono label below for status

**Animation.** Score number rolls (`DS.Motion.scoreChange`); arc length tweens with same curve.

**Watch usage.** Forbidden — Watch shows the bare number, no dial.

---

## P8 · `VitalChip`

**Job.** Compact vital readout — fits in the 2-column vitals grid.

**Inputs.** `label: String` (localized) · `value: String` · `unit: String?` · `trend: TrendDirection` · `polarity: Polarity` · `sub: String?` · `onTap: (() -> Void)? = nil`

**Composition.**
- Top row: `MonoLabel` (label) — left-aligned, `chinese:` aware
- Middle row: `BigNum` `.title1` (value) + small unit
- Right side aligned with middle: `TrendArrow` matching polarity
- Bottom row: `Caption` `inkDim` for `sub` (e.g. "+6 vs 30d baseline")

**Card.** Wrapped in `Card` with `padding: DS.Spacing.card`.

---

## P9 · `ScoreChart`

**Job.** Multi-day score trend (30 days default).

**Inputs.** `data: [(day: Date, value: Int)]` · `height: CGFloat = 130`

**Composition.**
- Path through values, stroke `chartHeavy`, color `ink`
- Filled area below at `0.05` opacity
- Dashed baseline at average value, `lineSoft`
- Terminal point dot, `r=3`, color `accent`
- First/last date labels in mono below

**Interaction.** Drag to scrub → highlight closest point; emit `onScrub(date, value)`.

**Forbidden.** Grid. Y-axis labels. Legend. Bar version.

---

## P10 · `SleepBand`

**Job.** Last night sleep stage timeline.

**Inputs.** `data: [SleepStage]` where each is `(stage: .awake|.core|.rem|.deep, mins: Int)` · `height: CGFloat = 60`

**Composition.** 4 horizontal lanes (top→bottom: awake, REM, core, deep). Each segment's x-extent proportional to `mins / total`; rendered as filled rect with `DS.Radius.chipIcon` corners.

**Stage colors.**
- `deep` → `DS.Color.ink`
- `core` → `DS.Color.inkMid`
- `rem` → `DS.Color.accent`
- `awake` → `DS.Color.inkDim`

---

## P11 · `HeroScore`

**Job.** Today screen hero — score + status + insight + 30d sparkline.

**Inputs.** `score: Int` · `status: String` · `insight: LocalizedInsight` · `lang: Lang`

**Composition.**
- Top: MonoLabel `"TODAY · MAY 5"` aligned to `DS.Spacing.edge`
- Center: `ScoreDial` 240pt
- Below: `BodyL` for insight (verb-first), centered, max 2 lines
- Below: 30d `Sparkline` (thin) + label `MonoLabel` "30d trend"

**Layout.** Vertical, full-width, top padding `DS.Spacing.xxl`.

---

## P12 · `Insight`

**Job.** A one-line action sentence.

**Inputs.** `text: String` (localized; verb-first) · `cta: String? = nil`

**Constraints.** Must start with a verb (validate at compile-time via a lint, see RULES.md). Never a number.

---

## P13 · `HRZoneRing`

**Job.** 5-zone heart-rate ring with current HR pointer.

**Inputs.** `currentHR: Int` · `maxHR: Int` · `zoneSamples: [HRZoneSample]?`

**Composition.** Circle split into 5 arcs proportional to standard zone widths (Z1 50–60%, Z2 60–70%, Z3 70–80%, Z4 80–90%, Z5 90–100%). Pointer dot at `currentHR / maxHR`. Center: BigNum `display3`.

**Zone colors.** Z1 `lineSoft` · Z2 `inkDim` · Z3 `accent` · Z4 `warn` · Z5 `bad`.

---

## P14 · `Timeline`

**Job.** Vertical event flow (recovery / anomaly).

**Inputs.** `events: [TimelineEvent]` where each has `time, title, detail, impact: .positive|.negative|.neutral, isCurrent: Bool`

**Row composition.** 8pt impact dot · 12pt gap · title (`Body`) above · detail (`BodyS .inkMid`) below · time at row right (`MonoLabel inkDim`).

**Forbidden.** Icons on rows. Card-per-row. Avatars.

---

## P15 · `Chip`

**Job.** Pill status badge or quick-prompt.

**Inputs.** `text: String` · `style: ChipStyle` (`.neutral | .accent | .good | .warn | .bad`)

**Surface.** `DS.Radius.pill`, padding horizontal `DS.Spacing.s`, vertical `DS.Spacing.xs`. Mono `10pt`. Background per style.

**Color matrix.**
| style    | bg               | fg               |
|----------|------------------|------------------|
| neutral  | `chipBg`         | `inkMid`         |
| accent   | `accent`         | `accentInk`      |
| good     | `good` @ 0.15    | `good`           |
| warn     | `warn` @ 0.15    | `warn`           |
| bad      | `bad` @ 0.15     | `bad`            |

---

## Cross-cutting: Failure States

Each component must define behaviour for these data conditions (see DESIGN §9):
1. **No data** — render `MonoLabel "AWAITING DATA"` in place of value.
2. **Loading** — static placeholder + mono `"loading…"`. No skeleton shimmer.
3. **Error** — `Chip(.warn)` with action.
4. **Stale** (data > 6h old) — `Chip(.neutral)` "stale".
5. **Demo** — uniform demo banner is on screen, components don't repeat the marker.

A component without these states is incomplete and fails review.
