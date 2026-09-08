# Plate

A personal iOS app for low-friction weight, meal, and training tracking.

**Status:** Core MVP implemented — daily weight, quick meal reuse, AI photo estimates, editable workout logs, and 7/30-day trends.

See [`docs/plans/2026-05-27-plate-design.md`](docs/plans/2026-05-27-plate-design.md) for the full design.

## Stack
- Swift + SwiftUI
- SwiftData (local device storage)
- iOS 17+
- OpenAI Responses API through an optional server-side proxy

## AI meal estimates

Plate can estimate calories and protein from a meal photo or short description.
The API key is never stored in the iOS app. Deploy the small proxy in
[`backend`](backend/README.md), then paste its endpoint into the app's daily
goal settings.

## Why
Plate keeps the daily loop small: log weight, roughly capture calories and protein, reuse the last workout, and judge progress from trends instead of a misleading one-day calorie-burn estimate.
