import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: Tab = .workout
    @Environment(\.modelContext) private var modelContext

    enum Tab { case workout, history, progress, library, profile }

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutTabView()
                .tabItem { Label("Train", systemImage: "dumbbell") }
                .tag(Tab.workout)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
                .tag(Tab.history)

            ProgressView()
                .tabItem { Label("Progress", systemImage: "chart.bar") }
                .tag(Tab.progress)

            LibraryView()
                .tabItem { Label("Library", systemImage: "book") }
                .tag(Tab.library)

            ProfileView(selectedTab: $selectedTab)
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(Tab.profile)
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
        Picker("Library section", selection: $selection) {
            ForEach(LibraryView.Section.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, VoltSpacing.gutter)
        .padding(.top, VoltSpacing.xs)
        .padding(.bottom, VoltSpacing.sm)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkoutSession.self, Exercise.self, Routine.self], inMemory: true)
        .environment(SupabaseManager.shared)
}
