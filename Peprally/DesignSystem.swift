import SwiftUI

// The peprally design system, written down. Everything here was extracted
// from the screens the app already has — this file names the decisions the
// eye was already making, and fixes the few places they drifted.
//
// Rules of thumb:
//  · Strictly monochromatic: ink, white, and grey only — no hue in chrome
//    OR content, badges included. Destructive red is the single sanctioned
//    semantic exception. The dots are the only character.
//  · Tracking: display text runs −4% of point size, standard text −2%.
//  · Spacing sits on a 4pt base scale.
//  · Text tones have a contrast floor — see Ink.

// MARK: - Ink (text on white)

/// Text tones. Contrast ratios against white are noted; the floor is
/// AA (4.5:1) for standard text. Tones below the floor are restricted:
/// `tertiary` only at ≥15pt semibold (large-text threshold, 3:1),
/// `hint` only for placeholders and disabled states.
enum Ink {
    /// 19.6:1 — headlines and primary copy (equal-channel, no cool cast)
    static let primary = Color(red: 0.035, green: 0.035, blue: 0.035)
    /// 4.6:1 — secondary copy, meets AA at any size
    static let secondary = Color.black.opacity(0.54)
    /// 2.8:1 — large/semibold secondary text only
    static let tertiary = Color.black.opacity(0.38)
    /// 2.1:1 — placeholders and disabled labels only
    static let hint = Color.black.opacity(0.28)
    /// text on charcoal fills
    static let onDark = Color.white
    static let onDarkSecondary = Color.white.opacity(0.6)
}

// MARK: - Fills

enum Fill {
    /// cards and grouped backgrounds
    static let subtle = Color.black.opacity(0.035)
    /// inputs and ghost buttons
    static let regular = Color.black.opacity(0.05)
    /// inactive indicators, separators
    static let strong = Color.black.opacity(0.12)
    /// the one action color
    static let charcoal = Color(red: 0.18, green: 0.18, blue: 0.18)
    /// grey circle behind avatar initials (opacity-based so it composites
    /// correctly on any ground; keep in the light band or initials fail contrast)
    static let avatarNeutral = Color.black.opacity(0.06)
}

// MARK: - Accents — neutralized to ink (strict monochrome)

/// The former accent hues now resolve to ink, so every historical call-site
/// (verified seals, feature icons, verification/mod checks) renders monochrome
/// with zero call-site churn. `danger` is the single sanctioned semantic
/// exception — destructive controls only, never validation or decoration.
enum Accent {
    static let info = Ink.primary
    static let success = Ink.primary
    static let ask = Ink.primary
    /// the one sanctioned hue — destructive actions only (delete, block)
    static let danger = Color(red: 0.90, green: 0.24, blue: 0.24)
}

// MARK: - Brand

enum Brand {
    /// loading screen / icon gradient
    static let haze = LinearGradient(
        stops: [
            .init(color: Color(red: 208/255, green: 208/255, blue: 208/255), location: 0),
            .init(color: Color(red: 226/255, green: 226/255, blue: 226/255), location: 1),
        ],
        startPoint: .top, endPoint: .bottom
    )
}

// MARK: - Type

/// The type ramp. Tracking slopes with size: display −3%, standard −1%,
/// footnote neutral — SF Text is already snug at small sizes, so the
/// tightness lives where it reads as a choice, not a squeeze.
/// Weights: bold is reserved for display, medium is the working weight,
/// semibold marks emphasis — regular is never used.
enum PepText {
    case display    // 24 bold  −0.72 · screen titles
    case title      // 20 bold  −0.60 · section titles
    case lead       // 16 semibold −0.40 · sublines under display
    case body       // 15 medium −0.15 · running copy
    case label      // 14 medium −0.14 · list titles, emphasis rows
    case caption    // 13 medium −0.13 · metadata, footers
    case footnote   // 12 medium  0.00 · smallest copy

    var font: Font {
        switch self {
        case .display:  .system(size: 24, weight: .bold)
        case .title:    .system(size: 20, weight: .bold)
        case .lead:     .system(size: 16, weight: .semibold)
        case .body:     .system(size: 15, weight: .medium)
        case .label:    .system(size: 14, weight: .medium)
        case .caption:  .system(size: 13, weight: .medium)
        case .footnote: .system(size: 12, weight: .medium)
        }
    }

    var tracking: CGFloat {
        switch self {
        case .display: -0.72
        case .title:   -0.60
        case .lead:    -0.40
        case .body:    -0.15
        case .label:   -0.14
        case .caption: -0.13
        case .footnote: 0
        }
    }
}

extension View {
    func pepText(_ style: PepText, _ tone: Color = Ink.primary) -> some View {
        self.font(style.font)
            .tracking(style.tracking)
            .foregroundStyle(tone)
    }
}

// MARK: - Spacing (4pt base)

enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let x2l: CGFloat = 24
    static let x3l: CGFloat = 32
    static let x4l: CGFloat = 40
    /// screen edge margin
    static let margin: CGFloat = 24
}

// MARK: - Radii & control metrics

/// One radius everywhere: every rounded rectangle in the app is 14.
/// (Buttons and chips are capsules — pills, not corner-radius surfaces.)
enum Radius {
    static let input: CGFloat = 14
    static let card: CGFloat = 14
}

enum Metrics {
    /// visual heights
    static let compactControl: CGFloat = 38
    static let control: CGFloat = 44
    static let input: CGFloat = 52
    static let chip: CGFloat = 36
    /// minimum tappable height (HIG) — button styles pad hit areas to this
    static let hitTarget: CGFloat = 44
}

// MARK: - Motion

enum Motion {
    /// the entrance cascade spring (see Entrance)
    static let entrance = Animation.spring(response: 0.95, dampingFraction: 0.9)
    /// selection, toggles
    static let select = Animation.spring(response: 0.3, dampingFraction: 0.8)
    /// in-place content swaps
    static let fast = Animation.easeInOut(duration: 0.3)
    /// stage changes within a flow
    static let medium = Animation.easeInOut(duration: 0.45)
    /// root crossfades (loading → app)
    static let slow = Animation.easeInOut(duration: 0.7)
    /// page pushes — a surface slides over cleanly, no crossfade
    static let push = Animation.easeOut(duration: 0.32)
}

// MARK: - Chrome

/// The circular back chip, top-left of every stepped screen.
struct PepBackChip: View {
    let action: () -> Void

    var body: some View {
        HStack {
            Button(action: action) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Ink.primary)
                    .frame(width: 44, height: 44)
                    .background(Fill.subtle, in: Circle())
            }
            Spacer()
        }
        .frame(height: 44)
    }
}

// MARK: - Buttons

/// The capsule button. Two roles (charcoal primary, 5%-black ghost) and
/// two sizes. Regular is 44pt with a 14pt semibold label — the CTA label
/// outranks nearby captions, and the height IS the HIG hit target.
/// Disabled renders as a light-gray capsule with muted text.
struct PepButtonStyle: ButtonStyle {
    enum Role { case primary, ghost }
    enum Size { case compact, regular }

    var role: Role = .primary
    var size: Size = .regular

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size == .compact ? .system(size: 12, weight: .medium)
                                   : .system(size: 14, weight: .semibold))
            .tracking(size == .compact ? -0.12 : -0.14)
            .foregroundStyle(labelColor)
            .frame(maxWidth: .infinity)
            .frame(height: size == .compact ? Metrics.compactControl : Metrics.control)
            .background(fillColor, in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }

    private var labelColor: Color {
        if !isEnabled { return Ink.hint }
        return role == .primary ? Ink.onDark : Ink.primary
    }

    private var fillColor: Color {
        if !isEnabled { return Color.black.opacity(0.05) }
        return role == .primary ? Fill.charcoal : Color.black.opacity(0.05)
    }
}

extension ButtonStyle where Self == PepButtonStyle {
    static var pepPrimary: PepButtonStyle { .init(role: .primary, size: .regular) }
    static var pepGhost: PepButtonStyle { .init(role: .ghost, size: .regular) }
    static var pepCompact: PepButtonStyle { .init(role: .primary, size: .compact) }
    static var pepCompactGhost: PepButtonStyle { .init(role: .ghost, size: .compact) }
}
