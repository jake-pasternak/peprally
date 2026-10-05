import SwiftUI

/// A rendered reference of DesignSystem.swift, for review — not shipped UI.
/// Launch with DESIGN_GALLERY=1 (tokens) or =2 (components) in the scheme
/// environment, or via `SIMCTL_CHILD_DESIGN_GALLERY=… simctl launch`.
struct DesignSystemGallery: View {
    let page: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.x2l) {
                Text(page == 1 ? "Tokens" : "Components")
                    .pepText(.display)
                    .padding(.top, Space.lg)

                if page == 1 { tokensPage } else { componentsPage }
            }
            .padding(.horizontal, Space.margin)
            .padding(.bottom, Space.x4l)
        }
        .background(Color.white)
    }

    // MARK: page 1 — color + type

    private var tokensPage: some View {
        VStack(alignment: .leading, spacing: Space.x2l) {
            section("Ink — text tones") {
                inkRow("Ink.primary", Ink.primary, "19.6:1 · anything")
                inkRow("Ink.secondary", Ink.secondary, "4.6:1 · AA, any size")
                inkRow("Ink.tertiary", Ink.tertiary, "2.8:1 · ≥15pt semibold only")
                inkRow("Ink.hint", Ink.hint, "2.1:1 · placeholders only")
            }

            section("Fills") {
                HStack(spacing: Space.md) {
                    fillSwatch("subtle", Fill.subtle)
                    fillSwatch("regular", Fill.regular)
                    fillSwatch("strong", Fill.strong)
                    fillSwatch("charcoal", Fill.charcoal)
                }
            }

            section("Accents — content only") {
                HStack(spacing: Space.md) {
                    fillSwatch("info", Accent.info)
                    fillSwatch("success", Accent.success)
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Brand.haze)
                            .frame(width: 64, height: 44)
                        Text("Brand.haze").pepText(.footnote, Ink.secondary)
                    }
                }
            }

            section("Type ramp — display −3%, standard −1%") {
                VStack(alignment: .leading, spacing: Space.md) {
                    typeRow("display · 24 bold −0.72", .display)
                    typeRow("title · 20 bold −0.60", .title)
                    typeRow("lead · 16 semibold −0.40", .lead)
                    typeRow("body · 15 medium −0.15", .body)
                    typeRow("label · 14 medium −0.14", .label)
                    typeRow("caption · 13 medium −0.13", .caption)
                    typeRow("footnote · 12 medium 0", .footnote)
                }
            }
        }
    }

    // MARK: page 2 — components + spacing + motion

    private var componentsPage: some View {
        VStack(alignment: .leading, spacing: Space.x2l) {
            section("Buttons — 38/46 visual, 44 hit area") {
                VStack(spacing: Space.sm) {
                    Button("Primary · regular") {}.buttonStyle(.pepPrimary)
                    Button("Ghost · regular") {}.buttonStyle(.pepGhost)
                    Button("Primary · compact") {}.buttonStyle(.pepCompact)
                    Button("Ghost · compact") {}.buttonStyle(.pepCompactGhost)
                }
            }

            section("Input · Radius.input 14") {
                Text("Email address")
                    .pepText(.body, Ink.hint)
                    .padding(.horizontal, 18)
                    .frame(height: Metrics.input)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Fill.regular,
                                in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            }

            section("Chips") {
                HStack(spacing: Space.sm) {
                    chip("BPC-157", selected: true)
                    chip("Semaglutide", selected: false)
                    chip("NAD+", selected: false)
                }
            }

            section("Card · Radius.card 16 · Fill.subtle") {
                HStack(spacing: 14) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Accent.info)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Vetted answers").pepText(.label)
                        Text("From verified experts.").pepText(.footnote, Ink.secondary)
                    }
                    Spacer()
                }
                .padding(Space.lg)
                .background(Fill.subtle,
                            in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            }

            section("Spacing — 4pt base") {
                VStack(alignment: .leading, spacing: 6) {
                    spaceBar("xs 4", Space.xs);  spaceBar("sm 8", Space.sm)
                    spaceBar("md 12", Space.md); spaceBar("lg 16", Space.lg)
                    spaceBar("xl 20", Space.xl); spaceBar("x2l 24", Space.x2l)
                    spaceBar("x3l 32", Space.x3l)
                }
            }

            section("Motion") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("entrance · spring 0.95 / 0.9 — cascade in").pepText(.caption, Ink.secondary)
                    Text("select · spring 0.30 / 0.8 — toggles").pepText(.caption, Ink.secondary)
                    Text("fast 0.3 · medium 0.45 · slow 0.7 — swaps, stages, roots").pepText(.caption, Ink.secondary)
                }
            }
        }
    }

    // MARK: helpers

    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text(title).pepText(.caption, Ink.tertiary)
            content()
        }
    }

    private func inkRow(_ name: String, _ tone: Color, _ note: String) -> some View {
        HStack {
            Text("Every question answered.").pepText(.body, tone)
            Spacer()
            Text(note).pepText(.footnote, Ink.tertiary)
        }
    }

    private func fillSwatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 10).fill(color).frame(width: 64, height: 44)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Fill.strong, lineWidth: 0.5))
            Text(name).pepText(.footnote, Ink.secondary)
        }
    }

    private func typeRow(_ name: String, _ style: PepText) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Join the rally").pepText(style)
            Text(name).pepText(.footnote, Ink.tertiary)
        }
    }

    private func chip(_ name: String, selected: Bool) -> some View {
        Text(name)
            .pepText(.caption, selected ? Ink.onDark : Ink.secondary)
            .padding(.horizontal, 14)
            .frame(height: Metrics.chip)
            .background(selected ? Fill.charcoal : Fill.regular, in: Capsule())
    }

    private func spaceBar(_ name: String, _ value: CGFloat) -> some View {
        HStack(spacing: Space.md) {
            Text(name).pepText(.footnote, Ink.secondary).frame(width: 56, alignment: .leading)
            RoundedRectangle(cornerRadius: 2).fill(Fill.charcoal).frame(width: value * 4, height: 8)
        }
    }
}

#Preview("Tokens") { DesignSystemGallery(page: 1) }
#Preview("Components") { DesignSystemGallery(page: 2) }
