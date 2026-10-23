import SwiftUI
import UIKit

// MARK: - Hex Colour Helpers
extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }

    /// A colour that switches with the system light / dark appearance.
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: String) {
        let v = Scanner(string: hex)
        var rgb: UInt64 = 0
        v.scanHexInt64(&rgb)
        self.init(
            red:   CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8)  & 0xFF) / 255,
            blue:  CGFloat( rgb        & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Colour Tokens
// Clean & minimal: quiet neutrals, ink for primary actions, one blue accent for live state.
// Every token adapts to light and dark mode.
enum VoltColor {
    // Backgrounds
    static let bg           = Color(light: "F5F6F8", dark: "0B0C0E")
    static let surface      = Color(light: "FFFFFF", dark: "16181C")
    static let surfaceHigh  = Color(light: "EEF0F3", dark: "202329")   // input fills, secondary buttons
    static let border       = Color(light: "E3E5EA", dark: "262930")
    static let borderSubtle = Color(light: "EDEFF2", dark: "1D2024")

    // Ink — primary buttons and selected states (black in light mode, white in dark mode)
    static let ink   = Color(light: "121418", dark: "F2F3F5")
    static let onInk = Color(light: "FFFFFF", dark: "0B0C0E")

    // Accent — used sparingly: timers, links, chart highlights
    static let accent       = Color(light: "3352FF", dark: "7D8DFF")
    static let accentDim    = Color(light: "EBEEFF", dark: "1C2142")
    static let accentPurple = accent   // kept for older call sites; the redesign uses a single accent
    static let accentGreen  = success

    // Text
    static let label          = Color(light: "121418", dark: "F2F3F5")
    static let labelSecondary = Color(light: "5E6472", dark: "A3A9B5")
    static let labelTertiary  = Color(light: "9AA0AC", dark: "6A707C")

    // Semantic
    static let success     = Color(light: "17994A", dark: "3CCB70")
    static let successSoft = Color(light: "E5F5EB", dark: "10261A")
    static let warning     = Color(light: "C2410C", dark: "FF9F0A")
    static let danger      = Color(light: "D92D20", dark: "FF6E61")
    static let dangerSoft  = Color(light: "FDECEA", dark: "2E1512")

    // Chart bars that are not highlighted
    static let bar = Color(light: "D6DAE2", dark: "30343C")

    /// Muscle groups no longer get their own colours; tags are neutral so the screen stays calm.
    static func muscle(_ group: Exercise.MuscleGroup) -> Color { labelSecondary }
}

// MARK: - Gradients
// The redesign uses flat fills. These stay as single-colour "gradients" so existing call sites keep working.
enum VoltGradient {
    static let brand       = LinearGradient(colors: [VoltColor.ink, VoltColor.ink], startPoint: .top, endPoint: .bottom)
    static let brandSubtle = LinearGradient(colors: [VoltColor.accentDim, VoltColor.accentDim.opacity(0.2)], startPoint: .top, endPoint: .bottom)
    static let success     = LinearGradient(colors: [VoltColor.success, VoltColor.success], startPoint: .top, endPoint: .bottom)
    static let dark        = LinearGradient(colors: [VoltColor.bg, VoltColor.bg], startPoint: .top, endPoint: .bottom)
}

// MARK: - Spacing & Sizing
enum VoltSpacing {
    static let xs: CGFloat  = 4
    static let sm: CGFloat  = 8
    static let md: CGFloat  = 16
    static let lg: CGFloat  = 24
    static let xl: CGFloat  = 32
    static let xxl: CGFloat = 48

    static let gutter: CGFloat = 20

    static let radius: CGFloat   = 16
    static let radiusLg: CGFloat = 20
    static let radiusSm: CGFloat = 10
    static let radiusXs: CGFloat = 9
}

// MARK: - Typography
enum VoltFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    /// Numbers that line up (timers, weights, reps). Uses SF with tabular digits instead of a monospaced face.
    static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
}

// MARK: - View Modifiers

extension View {
    /// Plain card: white surface on the grey background, no border or shadow.
    func voltCard(padding: CGFloat = VoltSpacing.md) -> some View {
        self
            .padding(padding)
            .background(VoltColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: VoltSpacing.radius, style: .continuous))
    }

    /// Section title + content stacked vertically
    func voltSection(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VoltSectionTitle(title)
                .padding(.horizontal, VoltSpacing.gutter)
            self
        }
    }
}

// MARK: - Section Title
struct VoltSectionTitle: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(VoltColor.labelSecondary)
    }
}

// MARK: - Muscle Badge (neutral tag)
struct MuscleBadge: View {
    let group: Exercise.MuscleGroup

    var body: some View {
        Text(group.rawValue)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(VoltColor.surfaceHigh)
            .foregroundStyle(VoltColor.labelSecondary)
            .clipShape(Capsule())
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 13)
                .frame(height: 32)
                .background(isSelected ? VoltColor.ink : VoltColor.surface)
                .foregroundStyle(isSelected ? VoltColor.onInk : VoltColor.labelSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
