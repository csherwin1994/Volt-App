import SwiftUI
import SwiftData

@main
struct VoltApp: App {
    @State private var supabase = SupabaseManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(supabase)
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
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(VoltColor.onInk)
                }
                Text("Volt")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(VoltColor.label)
            }
        }
    }
}
