# Pulse — AI Health Agent for Apple Watch

## Vision
Turn Apple Watch into an AI-powered health agent. Not a dashboard — an agent that understands your body and tells you what to do.

## Core Principles
- **Buy-once, no subscription**
- **Data stays on device** (local-first)
- **Action over information** — don't show charts, give advice
- **Minimal UI** — glance and go

## Target Device
- Apple Watch Series 7 (primary dev device)
- Support Series 6+ (blood oxygen), SE 2+ (basic)

## Architecture

```
Apple Watch (Sensors + Complications + Minimal UI)
    ↓ WatchConnectivity
iPhone App (Core Brain)
    ├── HealthKit data collection
    ├── CoreLocation (geofence)
    ├── Local data store (SwiftData)
    ├── AI analysis engine (local + optional OpenClaw)
    └── Notification system
```

## MVP Features (Phase 1)

### 1. Silent Sensing (Background)
- Continuous HealthKit data: HR, HRV, sleep, steps, calories, blood oxygen
- Low-power geofencing for known locations
- Local SwiftData storage

### 2. Daily Intelligence
- **Morning Brief** (configurable time): sleep quality + recovery score + one-line advice
- **Anomaly alerts**: HRV drop, elevated resting HR, poor sleep streak
- **Weekly report**: trend card

### 3. Location-Aware Automation
- Arrive at gym → haptic + "Working out?" → auto-start Workout Session
- Today's training plan from AI (push/pull/legs rotation)
- Track workout history, suggest progressive overload (+2.5kg)
- Recovery-aware: bad sleep/low HRV → suggest lighter session
- Extensible: school → study mode, home → daily summary

### 4. Watch Complication
- Circular gauge: daily status score (0-100)
- Color-coded (green/yellow/red)
- Tap → 3-line summary + action button

### 5. OpenClaw Integration (Optional)
- User opts in to share health context with their agent
- Agent becomes body-aware: adjusts behavior based on health state
- API endpoint for agent to query health status

## Tech Stack
- SwiftUI (iOS 17+ / watchOS 10+)
- SwiftData for local persistence
- HealthKit
- CoreLocation (geofencing)
- WatchConnectivity
- WidgetKit (complications)

## File Structure
```
PulseWatch/
├── Shared/              # Shared models, utilities
│   ├── Models/
│   ├── Services/
│   └── Extensions/
├── PulseWatch/          # iPhone app
│   ├── App/
│   ├── Views/
│   ├── ViewModels/
│   └── Services/
├── PulseWatchWatch/     # watchOS app  
│   ├── App/
│   ├── Views/
│   ├── Complications/
│   └── Services/
└── PulseWatchTests/
```
