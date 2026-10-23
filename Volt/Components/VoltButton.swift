import SwiftUI

// MARK: - Primary Button
struct VoltButton: View {
    /// primary: ink fill · gold: achievement (Finish) · secondary: 1px outline · ghost: text only · danger: red outline
    enum Style { case primary, gold, secondary, ghost, danger }

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
            // Label on the left, arrow on the right: square buttons that point forward
            HStack(spacing: VoltSpacing.sm) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .regular)) }
                Text(title).font(VoltFont.sans(17))
                Spacer(minLength: 12)
                if isLoading {
                    // Fully qualified: the app's own ProgressView (the Progress tab) shadows SwiftUI's spinner
                    SwiftUI.ProgressView().tint(foregroundColor).scaleEffect(0.85)
                } else if style != .ghost {
                    Image(systemName: "arrow.right").font(.system(size: 15, weight: .light))
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .overlay(Rectangle().strokeBorder(borderColor, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: VoltColor.ink
        case .gold:    VoltColor.accent
        default:       Color.clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:   VoltColor.onInk
        case .gold:      VoltColor.onAccent
        case .secondary: VoltColor.label
        case .ghost:     VoltColor.label
        case .danger:    VoltColor.danger
        }
    }

    private var borderColor: Color {
        switch style {
        case .secondary: VoltColor.label
        case .danger:    VoltColor.danger
        default:         Color.clear
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
                .font(VoltFont.sans(17, weight: .regular))
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
