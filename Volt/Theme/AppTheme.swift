import SwiftUI
import UIKit
import CoreText

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
    /// Paper: the screen background
    static let bg             = Color(light: "EFEEE9", dark: "0F0F0E")
    /// Raised paper: the set table, sheets, input fields
    static let surface        = Color(light: "FAFAF7", dark: "191917")
    /// Graphite tint: secondary buttons, empty fields, untrained days
    static let surfaceHigh    = Color(light: "E3E2DC", dark: "24241F")
    /// Hairline rules between rows and around spec grids
    static let border         = Color(light: "D3D2CB", dark: "2E2E2A")
    /// Faint rules inside grids
    static let borderSubtle   = Color(light: "E3E2DC", dark: "24241F")
    /// Graphite: primary buttons, selected states, the rest bar
    static let ink            = Color(light: "141413", dark: "F1F0EA")
    /// Text and icons on ink
    static let onInk          = Color(light: "FAFAF7", dark: "0F0F0E")
    /// Performance Gold, used as a fill: done sets, Finish, PRs, the current week
    static let accent         = Color(light: "E3A33A", dark: "F0B24A")
    /// Text and icons on gold
    static let onAccent       = Color(light: "141413", dark: "0F0F0E")
    /// Gold as text or a thin line on paper (gold fills are too light for text)
    static let accentText     = Color(light: "8A5B0E", dark: "F0B24A")
    /// Gold wash: completed set rows, chart area fills
    static let accentDim      = Color(light: "F5E6C8", dark: "2E2414")
    /// Primary text
    static let label          = Color(light: "141413", dark: "F1F0EA")
    /// Secondary text and mono labels
    static let labelSecondary = Color(light: "57564F", dark: "A8A79F")
    /// Hints, column headers, inactive tabs (4.5:1 on bg and surface)
    static let labelTertiary  = Color(light: "6A6962", dark: "8D8C85")
    /// Done: same gold as accent (Finish button, completed tick)
    static let success        = Color(light: "E3A33A", dark: "F0B24A")
    /// Text and icons on success
    static let onSuccess      = Color(light: "141413", dark: "0F0F0E")
    /// Completed set row background
    static let successSoft    = Color(light: "F5E6C8", dark: "2E2414")
    /// Warnings
    static let warning        = Color(light: "A8541A", dark: "E8A15C")
    /// Destructive actions only: discard, delete, sign out
    static let danger         = Color(light: "B3261E", dark: "F08A7E")
    /// Destructive button background
    static let dangerSoft     = Color(light: "F3E1DE", dark: "2D1916")
    /// Chart bars that are not highlighted
    static let bar            = Color(light: "CFCEC6", dark: "34342F")
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
    static let gutter: CGFloat = 20
    static let radiusXs: CGFloat = 2
    static let radiusSm: CGFloat = 2
    static let radius: CGFloat = 0
    static let radiusLg: CGFloat = 0
    // END GENERATED TOKENS
}

// MARK: - Typography
// Schibsted Grotesk for words and big numerals, Geist Mono for data and labels (both SIL OFL, bundled in Resources/Fonts).
enum VoltFont {
    static let sansFamily = "Schibsted Grotesk"
    static let monoFamily = "Geist Mono"

    /// Registers the bundled fonts for this process. Call once at launch; no Info.plist entry needed.
    static func registerFonts() {
        for name in ["SchibstedGrotesk", "GeistMono"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(sansFamily, size: size).weight(weight)
    }
    /// Big numerals and titles. Pair with a negative `tracking` that grows with size (see design/tokens.json).
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        sans(size, weight: weight).monospacedDigit()
    }
    /// Numbers and labels that line up: weights, reps, timers, UPPERCASE section labels.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(monoFamily, size: size).weight(weight).monospacedDigit()
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
        Text(title.uppercased())
            .font(VoltFont.mono(11, weight: .medium))
            .tracking(0.9)
            .foregroundStyle(VoltColor.labelSecondary)
    }
}

// MARK: - Muscle Badge (neutral tag)
struct MuscleBadge: View {
    let group: Exercise.MuscleGroup

    var body: some View {
        Text(group.rawValue.uppercased())
            .font(VoltFont.mono(11))
            .tracking(0.6)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(VoltColor.surfaceHigh)
            .foregroundStyle(VoltColor.labelSecondary)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(VoltFont.mono(11))
                .tracking(0.6)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(isSelected ? VoltColor.ink : Color.clear)
                .foregroundStyle(isSelected ? VoltColor.onInk : VoltColor.labelSecondary)
                .overlay(Rectangle().strokeBorder(isSelected ? Color.clear : VoltColor.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Appearance switch (Light / Dark / Auto)
/// Stored in `@AppStorage("appearance")` and applied app-wide in `VoltApp`.
struct AppearanceToggle: View {
    @AppStorage("appearance") private var appearance = "system"

    private struct Option: Identifiable { let id: String; let label: String }
    private let options = [Option(id: "light", label: "Light"), Option(id: "dark", label: "Dark"), Option(id: "system", label: "Auto")]

    static func colorScheme(for value: String) -> ColorScheme? {
        switch value {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil   // follow the device
        }
    }

    var body: some View {
        HStack(spacing: 1) {
            ForEach(options) { option in
                let selected = appearance == option.id
                Button { appearance = option.id } label: {
                    Text(option.label.uppercased())
                        .font(VoltFont.mono(10))
                        .tracking(0.8)
                        .padding(.horizontal, 10)
                        .frame(minWidth: 44, minHeight: 30)
                        .background(selected ? VoltColor.ink : VoltColor.bg)
                        .foregroundStyle(selected ? VoltColor.onInk : VoltColor.labelSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(1)
        .background(VoltColor.border)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Appearance")
    }
}
