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
            VStack(spacing: VoltSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(VoltGradient.brand)
                        .frame(width: 80, height: 80)
                    Image(systemName: "bolt.fill")
                        .font(VoltFont.sans(36, weight: .medium))
                        .foregroundStyle(VoltColor.onInk)
                }
                Text("Volt")
                    .font(VoltFont.sans(34, weight: .regular))
                    .foregroundStyle(VoltColor.label)
            }
        }
    }
}
