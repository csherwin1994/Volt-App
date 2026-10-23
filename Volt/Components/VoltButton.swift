import SwiftUI

// MARK: - Primary Button
struct VoltButton: View {
    enum Style { case primary, secondary, ghost, danger }

    let title: String
    let icon: String?
    let style: Style
    let isLoading: Bool
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        style: Style = .primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: VoltSpacing.sm) {
                if isLoading {
                    // Fully qualified: the app's own ProgressView (the Progress tab) shadows SwiftUI's spinner
                    SwiftUI.ProgressView()
                        .tint(foregroundColor)
                        .scaleEffect(0.85)
                } else {
                    if let icon { Image(systemName: icon).font(.system(size: 16, weight: .semibold)) }
                    Text(title).font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(backgroundView)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:   VoltColor.ink
        case .secondary: VoltColor.surfaceHigh
        case .ghost:     Color.clear
        case .danger:    VoltColor.dangerSoft
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:   VoltColor.onInk
        case .secondary: VoltColor.label
        case .ghost:     VoltColor.accent
        case .danger:    VoltColor.danger
        }
    }

}

// MARK: - Icon Button
struct VoltIconButton: View {
    let icon: String
    let action: () -> Void
    var tint: Color = VoltColor.labelSecondary

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews
#Preview {
    VStack(spacing: 12) {
        VoltButton("Start Workout", icon: "plus.circle.fill") {}
        VoltButton("Browse Routines", icon: "repeat", style: .secondary) {}
        VoltButton("Suggest Workout", icon: "sparkles", style: .ghost) {}
        VoltButton("Discard", style: .danger) {}
        VoltButton("Generating...", isLoading: true) {}
    }
    .padding()
    .background(VoltColor.bg)
}
