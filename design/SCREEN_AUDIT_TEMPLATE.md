# Screen Audit — Functional Preservation Checklist

> **Use this template at the start of every Phase 3 PR.**
> Copy it into the PR description, fill in every box from the OLD view, then build the NEW view to satisfy each item.
> No item left unaddressed = no merge.

---

## Screen ID
e.g. **S01 Today** — replacing `PulseWatch/Views/Screens/HomeView.swift` (+ `DashboardView.swift`)

---

## 1 · Data dependencies

Read the old view top to bottom. List every data source it touches.

- [ ] `@State` properties: …
- [ ] `@StateObject` / `@ObservedObject` / `@EnvironmentObject`: …
- [ ] `@Environment` keys: …
- [ ] `@Query` (SwiftData) sorts/predicates: …
- [ ] Services accessed (e.g. `HealthKitManager.shared`, `ScoreEngine`, `OpenClawBridge`, `StreakService`, `MorningBriefService`, `HealthAnalyzer`, `StrainScoreService`, `HealthAgeService`, `CorrelationService`, …): …
- [ ] Models read/written: …
- [ ] Background tasks / `BGTaskScheduler` IDs invoked: …
- [ ] App Group reads/writes: …

**Rule:** all of the above must work identically in the new view. Service signatures must NOT change.

---

## 2 · User interactions

Every place the user can poke the screen. Catalog from the old view, port to the new.

- [ ] Tap targets (buttons, rows, cells): …
- [ ] Long-press: …
- [ ] Drag / pan / swipe gestures: …
- [ ] Pinch / magnify: …
- [ ] Pull-to-refresh: …
- [ ] Chart scrubbing / point selection: …
- [ ] Edit / delete (rows, list items): …
- [ ] Keyboard / text input: …
- [ ] Focus management: …

---

## 3 · Navigation

- [ ] Every `NavigationLink` / `navigationDestination`: …
- [ ] Every `.sheet` / `.fullScreenCover` / `.alert` / `.popover` / `.confirmationDialog`: …
- [ ] Deep-link entry points (URL schemes, widget tap, complication tap, notification tap): …
- [ ] Tab switches initiated from this screen: …
- [ ] Back / dismiss behavior: …

---

## 4 · State coverage (visible variants)

Each must render correctly in the new view. Verify in `#Preview` + simulator.

- [ ] First-load (no data fetched yet)
- [ ] Empty data (HealthKit authorized but nothing to show)
- [ ] No HealthKit authorization
- [ ] No paired Watch (if Watch-aware)
- [ ] OpenClaw disconnected (if Coach-related)
- [ ] Demo mode active
- [ ] Stale data (>6h old)
- [ ] Error / fetch failed
- [ ] Loading (in-flight)
- [ ] Reduced Motion enabled
- [ ] Voice Over enabled
- [ ] Dynamic Type at XXL

---

## 5 · Side effects

The invisible work the screen does. Easy to drop in a rewrite.

- [ ] Haptic feedback triggers (`HapticManager`, `WKInterfaceDevice.current().play(_:)`): when, what kind?
- [ ] Notification scheduling / cancellation: …
- [ ] Analytics events (`Analytics.swift`): …
- [ ] HealthKit writes: …
- [ ] SwiftData writes: …
- [ ] UserDefaults writes: …
- [ ] Keychain writes: …
- [ ] Watch Connectivity messages sent/received: …
- [ ] Geofence registration changes: …

---

## 6 · Bilingual + a11y

- [ ] Every visible string is sourced from `Localizable.xcstrings` (key list pasted here): …
- [ ] zh-Hans render: no truncation, all glyphs present
- [ ] en render: no truncation
- [ ] VoiceOver labels for every interactive element
- [ ] Dynamic Type up to XXL — no clipping
- [ ] Reduce Motion — every animation has a static fallback
- [ ] Outdoor contrast (Watch only): legible at max brightness in lit room

---

## 7 · Lifecycle

- [ ] `onAppear` / `task` — what runs?
- [ ] `onDisappear` — what's cleaned up?
- [ ] Scene phase changes (`.background` / `.active`): any specific handling?

---

## 8 · Verification before merge

- [ ] New view renders all 12 state variants from §4
- [ ] Every item in §1–7 confirmed present in new view (manual walkthrough in simulator)
- [ ] Old view file(s) deleted from disk
- [ ] Routing updated to point at new view
- [ ] No remaining references to old view: `rg "OldViewName" PulseWatch PulseWatchWatch PulseWatchWidget Shared` returns empty
- [ ] `./Scripts/check-design-rules.sh <changed files>` returns 0
- [ ] Builds for iOS + watchOS + Widget targets, 0 warnings
- [ ] Bilingual screenshot pair attached to PR
- [ ] Light + dark screenshot pair attached to PR

---

## Out-of-scope reminder

- Service signatures: **don't change.**
- Model fields: **don't add.**
- Algorithms in DESIGN §5: **don't touch.**
- View-models: **don't refactor.**
- If you find yourself wanting to change any of the above — STOP and surface to user. That is a product decision, not a redesign decision.
