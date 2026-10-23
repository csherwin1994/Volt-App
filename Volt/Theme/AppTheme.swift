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
    // BEGIN GENERATED TOKENS
    /// Screen background: soft birch white / night forest
    static let bg             = Color(light: "F3F3EF", dark: "111513")
    /// Raised content when it must be set apart: inputs, the set table, sheets
    static let surface        = Color(light: "FFFFFF", dark: "191E1C")
    /// Input fields, secondary buttons, tags, untrained days
    static let surfaceHigh    = Color(light: "E8E8E2", dark: "232926")
    /// Hairline dividers between rows
    static let border         = Color(light: "DCDCD5", dark: "2B322E")
    /// Faint dividers
    static let borderSubtle   = Color(light: "E9E9E3", dark: "1F2522")
    /// Primary buttons, selected chips, rest bar (pine ink / pale birch)
    static let ink            = Color(light: "1B2421", dark: "E7ECE8")
    /// Text and icons on ink
    static let onInk          = Color(light: "F7F7F4", dark: "111513")
    /// Fjord blue: timers, links, current week in charts, PR trophy
    static let accent         = Color(light: "3A6787", dark: "8FB5D1")
    /// Chart area fill, accent tint
    static let accentDim      = Color(light: "E2EBF1", dark: "1C2933")
    /// Primary text
    static let label          = Color(light: "1B2421", dark: "E7ECE8")
    /// Secondary text, section titles
    static let labelSecondary = Color(light: "58615D", dark: "A3ACA7")
    /// Hints, column headers, inactive tabs (4.5:1 on bg and surface)
    static let labelTertiary  = Color(light: "67706B", dark: "8A938E")
    /// Moss green: Finish button, completed set tick
    static let success        = Color(light: "3B7A57", dark: "80C19A")
    /// Text and icons on success
    static let onSuccess      = Color(light: "FFFFFF", dark: "111513")
    /// Completed set row background
    static let successSoft    = Color(light: "E4EFE8", dark: "17271E")
    /// Warnings
    static let warning        = Color(light: "A8541A", dark: "E8A15C")
    /// Lingonberry: discard, delete, sign out
    static let danger         = Color(light: "B0362E", dark: "E68A80")
    /// Destructive button background
    static let dangerSoft     = Color(light: "F6E6E3", dark: "2B1A18")
    /// Chart bars that are not highlighted
    static let bar            = Color(light: "D6D6CF", dark: "2E3531")
    // END GENERATED TOKENS

    // Aliases kept for older call sites; the redesign uses a single accent
    static let accentPurple = accent
    static let accentGreen  = success

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
    // BEGIN GENERATED TOKENS
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let gutter: CGFloat = 24
    static let radiusXs: CGFloat = 10
    static let radiusSm: CGFloat = 12
    static let radius: CGFloat = 20
    static let radiusLg: CGFloat = 24
    // END GENERATED TOKENS
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
