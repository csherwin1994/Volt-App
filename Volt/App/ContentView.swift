import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: Tab = .workout
    @Environment(\.modelContext) private var modelContext

    enum Tab { case workout, history, progress, library, profile }

    private let tabs: [(tab: Tab, label: String)] = [
        (.workout, "Train"), (.history, "History"), (.progress, "Progress"), (.library, "Library"), (.profile, "Profile")
    ]

    var body: some View {
        // The system tab bar is hidden; VoltTabBar draws the text-only mono bar from the canvas.
        TabView(selection: $selectedTab) {
            WorkoutTabView().tag(Tab.workout).toolbar(.hidden, for: .tabBar)
            HistoryView().tag(Tab.history).toolbar(.hidden, for: .tabBar)
            ProgressView().tag(Tab.progress).toolbar(.hidden, for: .tabBar)
            LibraryView().tag(Tab.library).toolbar(.hidden, for: .tabBar)
            ProfileView(selectedTab: $selectedTab).tag(Tab.profile).toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VoltTabBar(tabs: tabs, selection: $selectedTab)
        }
        .tint(VoltColor.ink)
        .onAppear { DataManager.seedExercisesIfNeeded(context: modelContext) }
    }
}

// MARK: - Library (Exercises + Routines in one tab)

struct LibraryView: View {
    enum Section: String, CaseIterable, Identifiable {
        case exercises = "Exercises"
        case routines = "Routines"
        var id: String { rawValue }
    }

    @State private var section: Section = .exercises

    var body: some View {
        switch section {
        case .exercises: ExerciseLibraryView(librarySection: $section)
        case .routines:  RoutinesView(librarySection: $section)
        }
    }
}

/// Segmented control shown at the top of both Library screens.
struct LibrarySectionPicker: View {
    @Binding var selection: LibraryView.Section

    var body: some View {
        VoltSegmented(options: LibraryView.Section.allCases.map { (value: $0, label: $0.rawValue) }, selection: $selection)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkoutSession.self, Exercise.self, Routine.self], inMemory: true)
        .environment(SupabaseManager.shared)
}
