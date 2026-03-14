---
name: Pulse Watch Architecture
description: Key architecture decisions for the Pulse Watch iOS + watchOS project
type: project
---

Three-target xcodegen project: PulseWatch (iOS), PulseWatchWatch (watchOS), PulseWatchWatchWidgetExtension (complications).
**Why:** Shared/ directory contains models, services, theme used by all targets.
**How to apply:** When adding new shared code, put it in Shared/ and use `#if os(iOS)` / `#if os(watchOS)` for platform-specific code. CLMonitor (geofencing) is iOS-only. Run `xcodegen generate` after adding new files.
