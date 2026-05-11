# RULES — Hard Constraints + Verification

> Every Phase, every PR, every task: pass these rules or do not commit.
> Most rules are enforced by `Scripts/check-design-rules.sh`. Violating is not a stylistic complaint — it is a build break.

---

## R1 · Tokens are the only source of constants

The following are **forbidden** outside `Shared/Theme/DS.swift`:

| Forbidden pattern (regex)                  | Use instead                          |
|--------------------------------------------|--------------------------------------|
| `Color\(red:`                              | `DS.Color.<token>`                   |
| `Color\(hex:` / `Color\(rgb:`              | `DS.Color.<token>`                   |
| `Color\.\w+` for raw colors (e.g. `.blue`) | `DS.Color.<token>` (System grays in chrome only) |
| `\.padding\(\s*\d`                         | `.padding(DS.Spacing.<token>)`       |
| `\.cornerRadius\(\s*\d`                    | `.cornerRadius(DS.Radius.<token>)`   |
| `\.font\(\.system\(size:\s*\d`             | `.font(DS.Typography.<token>)`             |
| `\.frame\(width:\s*\d+,\s*height:\s*\d+\)` for icons | tokenized sizing or named constant |
| `\.shadow\(`                               | (forbidden entirely; see R7)         |

Exceptions:
- `DS.swift` itself
- Files in `design/reference/` (read-only, do not import)
- Test fixtures in `*Tests/Fixtures/`

## R2 · Single accent color

`DS.Color.accent` is the ONLY saturated color in the system. Adding any second saturated tone (a "secondary accent", a "highlight blue") is a design break. Status colors (`good`, `warn`, `bad`) are semantic-only — they appear on anomalies, PRs, and threshold breaches. Never as decoration.

## R3 · Bilingual parity

Every screen must render correctly in both `zh-Hans` and `en`. The CI check runs both and screenshots both. A truncation in either language is a fail.

- New strings must be added to `Localizable.xcstrings` with non-empty values for both `zh-Hans` and `en`.
- Forbidden: hardcoded user-visible literals. Pattern: `Text\("[^"\\]*[^a-zA-Z0-9_\\]"` (Chinese chars or English sentences inside `Text("…")`).
- Required: `Text("…", comment: "…")` for short keys, or `String(localized: "…")`.

## R4 · Action-over-information audit

Every primary screen must have a verb-first one-line `Insight` visible without scrolling. The dashboard test enforces:

```
"Train hard." ✅
"Recover today." ✅
"Sleep more tonight." ✅
"82" ❌ (number, not action)
"Your HRV is 58ms" ❌ (description, not action)
```

This is reviewed in the PR template's design checklist.

## R5 · Three surfaces are equal

A change to iPhone that doesn't update Watch + Widget is incomplete. PR description must list how each of `iPhone`, `Watch`, `Widget`, `Complication` is affected (or "N/A — explain why").

## R6 · Reduce Motion is non-optional

Every animation must funnel through `DS.Motion.respecting(_:reduce:)`. Required usage:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
…
.animation(DS.Motion.respecting(DS.Motion.scoreChange, reduce: reduceMotion), value: score)
```

Audit grep: `\.animation\(\s*\.` outside `respecting` — fail.

## R7 · No drop shadows

`.shadow(` is forbidden in app code. Depth comes from `bgElev` / `bgSunk` and hairline borders. The only exception is iOS-system-controlled chrome (e.g. `.sheet` modal — handled by system).

## R8 · No emoji as UI

No emoji in user-facing strings, button labels, status indicators, or notifications. (Demo data may include them in user-content fields.) Audit grep: emoji unicode ranges in `Localizable.xcstrings` keys.

## R9 · No skeleton loading

Loading states use static MonoLabel `"loading…"` (lowercase, mono). No animated shimmers. No animated rings.

## R10 · Component completeness

A new component is not "done" until all 5 failure states (no-data, loading, error, stale, demo) are explicitly implemented and visible in `#Preview`. Reviewers confirm by toggling the preview's failure state picker.

## R11 · Functional preservation (the cardinal rule of this redesign)

**This redesign replaces UI only. Every functional behavior in the old view must continue to work in the new view, identically.**

- Services, models, and view-models: **untouched.** No signature change, no field added, no algorithm tweaked.
- Every Phase 3 PR begins with a **Screen Audit** filled in from the old view (template: `design/SCREEN_AUDIT_TEMPLATE.md`).
- The audit goes into the PR description. Each item is a checkbox; reviewer manually walks the simulator through each.
- A regression — any behavior present in the old view that doesn't work in the new view — is a merge-blocker, not a follow-up.
- If the redesign appears to require a service / model / algorithm change, **STOP** and surface to user before writing code. That is a product decision, not a redesign decision.

The previous attempt failed in part because rewrites silently dropped long-press gestures, haptic triggers, edge-case empty states, and deep-link targets. The audit template exists to make this auditable instead of hope-based.

---

## Acceptance gates per PR

Before requesting review, the author runs:

```bash
./Scripts/check-design-rules.sh
xcodebuild -scheme PulseWatch test -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Both must pass. If `check-design-rules.sh` reports violations, fix them. **Do not** add files to the script's exception list to silence violations — that is rule-laundering.

---

## Pre-commit hook (optional but recommended)

Install once:
```bash
ln -sf ../../Scripts/pre-commit ~/Projects/pulse-watch/.git/hooks/pre-commit
chmod +x ~/Projects/pulse-watch/Scripts/pre-commit
```

The hook runs `check-design-rules.sh` and rejects commits with violations.

---

## When a rule must be broken

This document is law within v1 of the redesign. If a real product need conflicts with a rule, **escalate to design lead and bump DESIGN.md version** before merging the exception. Do not silently bypass; do not introduce a "// MARK: - design exception" comment without a linked decision.

Acceptable record format in PR description:
```
DESIGN exception: rule R7 (no shadows) waived for live-workout system sheet.
Reason: <link to design discussion / decision>
DESIGN.md version: 1.1 (bumped this PR)
```
