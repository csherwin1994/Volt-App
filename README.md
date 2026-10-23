# Volt — Performance, tracked

A Hevy-inspired workout tracking app built with **SwiftUI** and **SwiftData**, targeting **iOS 17+**.

## Features

| Feature | Details |
|---|---|
| **Active Workout** | Log exercises, sets, reps & weight in real time |
| **Rest Timer** | Auto-starts after completing a set (90s default) |
| **Exercise Library** | 50+ pre-loaded exercises, filterable by muscle group |
| **Custom Exercises** | Create your own exercises |
| **Routines** | Build and reuse workout templates |
| **History** | Browse past workouts with full set details |
| **Progress Charts** | Weekly volume, 30-day heatmap, per-exercise strength trends |
| **Profile & Stats** | Total workouts, sets, volume — with streak tracking |

## Project Structure

```
Volt/
├── App/
│   ├── VoltApp.swift               # App entry point + SwiftData container
│   └── ContentView.swift           # Tab bar navigation
├── Models/
│   ├── Exercise.swift              # Exercise model (muscle group, equipment)
│   ├── WorkoutSession.swift        # WorkoutSession, ExerciseLog, WorkoutSet
│   └── Routine.swift              # Routine + RoutineExercise
├── ViewModels/
│   └── ActiveWorkoutViewModel.swift # Workout timer, set logic
├── Views/
│   ├── Workout/
│   │   ├── WorkoutTabView.swift    # Home tab (start workout / quick-start routine)
│   │   └── ActiveWorkoutView.swift # Full-screen active workout logger
│   ├── History/
│   │   └── HistoryView.swift       # Past workouts list + detail
│   ├── Exercises/
│   │   └── ExerciseLibraryView.swift # Browse / create exercises
│   ├── Routines/
│   │   └── RoutinesView.swift      # Create and manage routines
│   └── Profile/
│       └── ProfileView.swift       # Stats + settings
└── Persistence/
    └── DataManager.swift           # Seeds default exercise library
```

## Requirements

- **Mac with Xcode 15.4+**
- **iOS 17.0+** (uses SwiftData and `@Observable`)
- No third-party dependencies

## Getting Started

1. Clone this repo on your Mac
2. Open `Volt.xcodeproj` in Xcode
3. Select your iPhone or the iOS Simulator as the run destination
4. Press **Cmd + R** to build and run
5. On first launch the app auto-seeds 50+ exercises

> **Note:** To run on a real device you need a free Apple Developer account.
> Go to **Xcode → Signing & Capabilities**, set your Team, and the bundle ID `com.sherwinlabs.Volt` is already configured.

## Design

The app uses a clean, minimal look that follows the system light or dark mode:

- Quiet grey background with plain white (or dark grey) cards, no borders or gradients
- Black primary buttons in light mode (white in dark mode) and one blue accent for live state: timers, links and chart highlights
- Five tabs: **Train**, **History**, **Progress**, **Library** (exercises and routines) and **Profile**

All colours live in `Volt/Theme/AppTheme.swift` as light/dark pairs, so the look can be changed in one place.

An interactive web prototype of the design is in `prototype/volt-prototype.html`. Open it in any browser to click through the app with sample data.

## Personal records

When you tick a set that beats your previous best for that exercise, Volt shows a "New PR" banner and a trophy on the set.
A set counts as a record when it is heavier than any earlier set, or when its estimated 1-rep max (Epley formula) is higher.
Records also show in workout history and on each exercise's detail page (Library → exercise).

## Rest timer Live Activity

After you complete a set, the rest countdown appears on the Lock Screen and in the Dynamic Island, so you don't have to unlock your phone between sets.
The app side is already set up (`Volt/LiveActivity/`, and `NSSupportsLiveActivities` is on). The widget extension has to be added once in Xcode:

1. In Xcode choose **File → New → Target…**, pick **Widget Extension**, and name it `VoltRestTimerWidget`.
   Tick **Include Live Activity**, untick **Include Configuration App Intent**, and click **Activate** if asked.
2. Delete the Swift files Xcode generated inside the new `VoltRestTimerWidget` group (keep `Info.plist` and `Assets.xcassets`).
3. Drag `VoltRestTimerWidgetBundle.swift` and `RestTimerLiveActivityWidget.swift` from the repo's `VoltRestTimerWidget/` folder into that group, with only the **VoltRestTimerWidget** target ticked.
4. Select `Volt/LiveActivity/RestTimerAttributes.swift`, open the File inspector, and under **Target Membership** tick **VoltRestTimerWidget** as well as **Volt**.
5. Set the widget target's **Minimum Deployments** to iOS 17.0, then build and run the **Volt** scheme.

Without these steps the app still builds and the in-app rest timer works; only the Lock Screen countdown is missing.

## Architecture

- **MVVM** — Views observe `ActiveWorkoutViewModel` via `@Observable`
- **SwiftData** — All data persisted locally with automatic migrations
- **SwiftUI** — Declarative UI, NavigationStack, sheets, full-screen covers

## Roadmap / Next Steps

- [ ] Login / auth screens + cloud backup (Supabase)
- [ ] Profile photo support
- [ ] Strava integration
- [x] Personal records (PR) detection and badges during workouts
- [x] Rest timer Live Activity (Lock Screen and Dynamic Island)
- [ ] Apple Health sync
- [ ] Apple Watch companion app
- [ ] Plate calculator
- [ ] Body measurements & weight log
- [ ] Push notification reminders
