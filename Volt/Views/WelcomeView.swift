import SwiftUI

struct WelcomeView: View {
    @Binding var hasSeenWelcome: Bool

    private let features: [(icon: String, title: String, description: String)] = [
        ("dumbbell.fill",         "Track Every Lift",       "Log sets, reps, and weight for any exercise in your library."),
        ("repeat",                "Build Routines",          "Create structured templates and start workouts in seconds."),
        ("chart.line.uptrend.xyaxis", "Analyze Progress",   "Visualize volume trends and personal records over time.")
    ]

    var body: some View {
        ZStack {
            VoltColor.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: VoltSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(VoltGradient.brand)
                            .frame(width: 96, height: 96)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(VoltColor.onInk)
                    }

                    VStack(spacing: 6) {
                        Text("Welcome to Volt")
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(VoltColor.label)
                        Text("Your personal training companion")
                            .font(.subheadline)
                            .foregroundStyle(VoltColor.labelSecondary)
                    }
                }

                Spacer()

                // Feature highlights
                VStack(spacing: 12) {
                    ForEach(features, id: \.title) { feature in
                        FeatureRow(icon: feature.icon, title: feature.title, description: feature.description)
                    }
                }
                .padding(.horizontal, VoltSpacing.md)

                Spacer()

                // Get Started button
                Button {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        hasSeenWelcome = true
                    }
                } label: {
                    Text("Get Started")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(VoltGradient.brand)
                        .foregroundStyle(VoltColor.onInk)
                        .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radius))
                }
                .padding(.horizontal, VoltSpacing.md)
                .padding(.bottom, VoltSpacing.xxl)
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: VoltSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(VoltColor.accent.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(VoltColor.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VoltColor.label)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(VoltColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(VoltSpacing.md)
        .background(VoltColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radius))
        .overlay(
            RoundedRectangle(cornerRadius: VoltSpacing.radius)
                .stroke(VoltColor.border, lineWidth: 0.5)
        )
    }
}

#Preview("Welcome") {
    WelcomeView(hasSeenWelcome: .constant(false))
}
