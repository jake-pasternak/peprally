import SwiftUI

/// The rally's trust system, in code. Deliberately just two marks:
///
/// · CREDENTIALED (blue, apply + human review) — `verified`, carrying the
///   specific credential ("Physician", "Pharmacology PhD"). Clinician and
///   Researcher tiers both land here; the tier lives in the credential text.
/// · ROLE — `moderator`, appointed to keep the rally healthy. Shown only on
///   moderation actions and the profile, not on ordinary answers.
///
/// Everyone else is just a member — no badge. Kept simple on purpose.
enum TrustBadge: Equatable {
    case verified(credential: String)
    case moderator
}

/// One view for every badge. The blue seal is reserved for verified
/// professionals; the MOD tag marks moderators. `compact` renders the
/// inline form beside a name; full renders the profile chip.
struct TrustBadgeView: View {
    let badge: TrustBadge
    var compact = false

    var body: some View {
        switch badge {
        case .verified(let credential):
            if compact {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Accent.info)
            } else {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Accent.info)
                    Text("Verified · \(credential)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Ink.primary)
                }
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Fill.subtle, in: Capsule())
            }
        case .moderator:
            tag("MOD", color: Fill.charcoal, outline: false)
        }
    }

    private func tag(_ label: String, color: Color, outline: Bool) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.45)
            .foregroundStyle(outline ? color : Ink.onDark)
            .padding(.horizontal, 7)
            .frame(height: 18)
            .background(outline ? AnyShapeStyle(Color.clear) : AnyShapeStyle(color), in: Capsule())
            .overlay {
                if outline {
                    Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1)
                }
            }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 14) {
        HStack { Text("Dr. Sarah Chen").pepText(.caption)
                 TrustBadgeView(badge: .verified(credential: "Physician"), compact: true) }
        TrustBadgeView(badge: .verified(credential: "Physician"))
        TrustBadgeView(badge: .verified(credential: "Pharmacology PhD"))
        TrustBadgeView(badge: .moderator)
    }
    .padding()
}
