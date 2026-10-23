import SwiftUI
import SwiftData

@main
struct VoltApp: App {
    @State private var supabase = SupabaseManager.shared
    /// "system", "light" or "dark", set from the switch at the top of Train or in Profile.
    @AppStorage("appearance") private var appearance = "system"

    init() {
        VoltFont.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(supabase)
                .preferredColorScheme(AppearanceToggle.colorScheme(for: appearance))
        }
        .modelContainer(for: [
            WorkoutSession.self,
            Exercise.self,
            Routine.self
        ])
    }
}

// MARK: - Root view — auth gate

struct RootView: View {
    @Environment(SupabaseManager.self) private var supabase
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some View {
        switch supabase.authState {
        case .loading:
            splashScreen

        case .signedOut:
            LoginView()
                .transition(.opacity)

        case .signedIn:
            if hasSeenWelcome {
                ContentView()
                    .transition(.opacity)
            } else {
                WelcomeView(hasSeenWelcome: $hasSeenWelcome)
                    .transition(.opacity)
            }
        }
    }

    private var splashScreen: some View {
        ZStack {
            VoltColor.bg.ignoresSafeArea()
            HStack(spacing: 10) {
                Rectangle().fill(VoltColor.accent).frame(width: 12, height: 12)
                Text("Volt")
                    .font(VoltFont.sans(56)).tracking(-2.2)
                    .foregroundStyle(VoltColor.label)
            }
        }
    }
}
