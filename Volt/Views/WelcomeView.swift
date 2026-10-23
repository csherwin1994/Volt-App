import SwiftUI

// Shown once after the first sign-in. Same voice as the rest of the app: mono labels, hairline rules, one gold signal.
struct WelcomeView: View {
    @Binding var hasSeenWelcome: Bool

    private let features: [(title: String, description: String)] = [
        ("Track every lift", "Log sets, reps and weight for more than 870 exercises."),
        ("Know what to train", "Each day Volt suggests a workout from what you have already done."),
        ("See it move", "Volume, streaks and personal records, week by week.")
    ]

    var body: some View {
        ZStack {
            VoltColor.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Rectangle().fill(VoltColor.accent).frame(width: 8, height: 8)
                        Text("VOLT")
                            .font(VoltFont.mono(11)).tracking(0.9)
                            .foregroundStyle(VoltColor.labelSecondary)
                    }
                    Text("Train with\nprecision.")
                        .font(VoltFont.sans(56)).tracking(-2.2)
                        .foregroundStyle(VoltColor.label)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(spacing: 0) {
                    VoltRule(strong: true)
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        HStack(alignment: .top, spacing: 12) {
                            Text(String(format: "%02d", index + 1))
                                .font(VoltFont.mono(11)).foregroundStyle(VoltColor.accentText)
                                .frame(width: 18, alignment: .leading)
                                .padding(.top, 4)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(feature.title).font(VoltFont.sans(20)).tracking(-0.5).foregroundStyle(VoltColor.label)
                                Text(feature.description)
                                    .font(VoltFont.sans(15)).foregroundStyle(VoltColor.labelSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 16)
                        .accessibilityElement(children: .combine)
                        VoltRule()
                    }
                }

                Spacer()

                VoltButton("Get Started") {
                    withAnimation(.easeInOut(duration: 0.4)) { hasSeenWelcome = true }
                }
                .padding(.bottom, VoltSpacing.xl)
            }
            .padding(.horizontal, VoltSpacing.gutter)
        }
    }
}

#Preview("Welcome") {
    WelcomeView(hasSeenWelcome: .constant(false))
}
