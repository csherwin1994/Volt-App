import SwiftUI

/// Rule, large headline, one line of help, optional action. Same shape as the empty states on the canvas.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VoltRule(strong: true)
            Text(title)
                .font(VoltFont.sans(24)).tracking(-0.6)
                .foregroundStyle(VoltColor.label)
                .padding(.top, 14)
            Text(message)
                .font(VoltFont.sans(15)).lineSpacing(3)
                .foregroundStyle(VoltColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                VoltButton(actionTitle, style: .secondary, action: action)
                    .padding(.top, 10)
            }
        }
        .padding(VoltSpacing.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    EmptyStateView(
        icon: "clock",
        title: "No workouts yet.",
        message: "Your completed workouts will appear here. Start your first session to begin tracking.",
        actionTitle: "Start Workout",
        action: {}
    )
    .background(VoltColor.bg)
}
