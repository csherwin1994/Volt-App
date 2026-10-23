# Volt

SwiftUI + SwiftData workout tracker for iOS 17+. See README.md for features and setup.

## Design workflow

The look of the app is edited visually in two Claude artifacts and kept in sync with the code through one tokens file.

| What | Where |
| --- | --- |
| Colours, spacing, corner radius, type scale (source of truth) | `design/tokens.json` |
| Swift tokens (generated, between `GENERATED TOKENS` markers) | `Volt/Theme/AppTheme.swift` |
| Volt Design System artifact (tokens, components, guidelines) | https://claude.ai/artifact/4bxgDkEKbTh5i8MGGqA5BU |
| Volt App Screens design canvas (every screen, light and dark) | https://claude.ai/artifact/4n7REycPfzr8ffqi62PTuT |
| Clickable web prototype | `prototype/volt-prototype.html` |

Design direction: **Nordic Precision** (paper, graphite, one Performance Gold signal; Schibsted Grotesk + Geist Mono; square corners). The design system's README is the full guide.

Token names are identical everywhere: `surfaceHigh` in the artifacts is `VoltColor.surfaceHigh` in Swift.

### When a colour, spacing or radius is changed in the Design System artifact

1. Read the artifact's `project/tokens.json` with the Artifact tool (`action: "read"`, `path: "project/tokens.json"`).
2. Run `python3 design/ds_sync.py import <that file>`. It prints what changed, updates `design/tokens.json` and regenerates the Swift theme and the prototype.
3. Re-install the design system on the canvas (Design type instructions, "Installing a design system") so the canvas picks up the new copy.

### When a screen is changed on the design canvas

Read the changed `project/<Screen>.dc.html` artboard and apply the change to the matching SwiftUI view:

| Artboard | SwiftUI view |
| --- | --- |
| `Main.dc.html` (Train) | `Volt/Views/Workout/WorkoutTabView.swift` |
| `Workout.dc.html` | `Volt/Views/Workout/ActiveWorkoutView.swift` |
| `Exercise.dc.html` (the interactive template every exercise uses) | `ExerciseDetailView` and its parts in `Volt/Views/Exercises/ExerciseLibraryView.swift` |
| `History.dc.html` | `Volt/Views/History/HistoryView.swift` |
| `Progress.dc.html` | `Volt/Views/Progress/ProgressView.swift` |
| `Library.dc.html` | `Volt/Views/Exercises/ExerciseLibraryView.swift`, `Volt/Views/Routines/RoutinesView.swift` |
| `Profile.dc.html` | `Volt/Views/Profile/ProfileView.swift` |
| `TabBar.dc.html` | `Volt/App/ContentView.swift` |

Inline `var(--token)` values in an artboard map to `VoltColor.token`; px sizes map to points.

### When tokens are changed in code

Edit `design/tokens.json` (never the generated Swift lines), then:

```
python3 design/generate_theme.py          # updates Swift + prototype
python3 design/ds_sync.py export <dir>    # writes tokens.json + tokens.css for the Design System artifact
```

Publish the exported `tokens.json` and `tokens.css` to the Design System artifact under `project/`, then re-install it on the canvas.

`python3 design/generate_theme.py --check` exits non-zero if the generated code is out of date.
