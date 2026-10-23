import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: VoltSpacing.lg) {
            ZStack {
                Circle()
                    .fill(VoltColor.surfaceHigh)
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(VoltColor.labelSecondary)
            }

            VStack(spacing: VoltSpacing.xs) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(VoltColor.label)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(VoltColor.labelSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if let actionTitle, let action {
                VoltButton(actionTitle, action: action)
                    .frame(maxWidth: 220)
            }
        }
        .padding(VoltSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    EmptyStateView(
        icon: "clock",
        title: "No Workouts Yet",
        message: "Your completed workouts will appear here. Start your first session to begin tracking.",
        actionTitle: "Start Workout",
        action: {}
    )
    .background(VoltColor.bg)
}
