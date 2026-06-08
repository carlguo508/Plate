# Plate

A personal iOS app for tracking recipes, daily meals, and training in one closed loop.

**Status:** Design complete, implementation in progress (P0).

See [`docs/plans/2026-05-27-plate-design.md`](docs/plans/2026-05-27-plate-design.md) for the full design.

## Stack
- Swift + SwiftUI
- SwiftData (with CloudKit backup)
- iOS 17+
- OpenAI Responses API through an optional server-side proxy

## AI meal estimates

Plate can estimate calories and macros from a meal photo or short description.
The API key is never stored in the iOS app. Deploy the small proxy in
[`backend`](backend/README.md), then paste its endpoint into the app's daily
goal settings.

## Why
Existing fitness apps silo recipes, food logging, and training. Plate integrates all three, with first-class support for irregular sports scheduling (e.g. avoiding leg day before basketball).
