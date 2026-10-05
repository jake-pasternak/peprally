import SwiftUI
import PhotosUI

/// The credential-verification flow, offered to professionals after setup.
/// Three faces driven by AppStage.verify: intro (the tier system), the
/// credentials form, and the in-review state. Verification never blocks —
/// every exit lands on home.
struct VerificationFlow: View {
    @Environment(AppModel.self) private var model
    let step: VerifyStep

    var body: some View {
        ZStack {
            switch step {
            case .intro:       VerifyIntro()
            case .credentials: VerifyCredentials()
            case .review:      VerifyReview()
            }
        }
        .background(Color.white.ignoresSafeArea())
        .tint(Ink.secondary)
    }
}

// MARK: - Shared chrome

private struct VerifyTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).pepText(.display)
            Text(subtitle)
                .pepText(.body, Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Step 1 · intro (the tier system)

private struct VerifyIntro: View {
    @Environment(AppModel.self) private var model
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PepBackChip { model.advanceVerify(to: nil) }
                .padding(.top, Space.md)

            VerifyTitle(title: "Get verified",
                        subtitle: "One review, then every answer you give carries your credential")
                .padding(.top, Space.x2l)
                .entrance(appeared, delay: 0, blur: false)

            VStack(spacing: Space.sm) {
                tier("stethoscope", "Clinician", "Licensed to practice — MD, DO, NP, PA, RN, PharmD",
                     badge: .verified(credential: "Physician"))
                tier("testtube.2", "Researcher", "PhD or working scientist in a relevant field",
                     badge: .verified(credential: "Pharmacology PhD"))
            }
            .padding(.top, Space.x2l)
            .entrance(appeared, delay: 0.12, blur: false)

            Text("This confirms a professional credential — nothing more. Moderating the rally is a separate, volunteer role you can apply for in Settings.")
                .pepText(.footnote, Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.xl)
                .entrance(appeared, delay: 0.2, blur: false)

            Spacer()

            VStack(spacing: Space.sm) {
                Button("Start verification") { model.advanceVerify(to: .credentials) }
                    .buttonStyle(.pepPrimary)
                Button("Maybe later") { model.advanceVerify(to: nil) }
                    .buttonStyle(.pepGhost)
            }
            .padding(.bottom, Space.lg)
            .entrance(appeared, delay: 0.32, blur: false)
        }
        .padding(.horizontal, Space.margin)
        .onAppear { appeared = true }
    }

    private func tier(_ icon: String, _ title: String, _ subtitle: String,
                      badge: TrustBadge) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Ink.primary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).pepText(.label)
                Text(subtitle).pepText(.footnote, Ink.secondary)
                // the badge this tier actually grants
                TrustBadgeView(badge: badge)
                    .padding(.top, 7)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, Space.lg)
        .background(Fill.subtle,
                    in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

}

// MARK: - Step 2 · credentials

private struct VerifyCredentials: View {
    @Environment(AppModel.self) private var model
    @State private var appeared = false
    @State private var role: String?
    @State private var license = ""
    @State private var attachedName: String?
    @State private var showUploadOptions = false
    @State private var showPhotoPicker = false
    @State private var showFilePicker = false
    @State private var photoItem: PhotosPickerItem?
    @FocusState private var focused: Bool

    private var attached: Bool { attachedName != nil }

    private static let roles = [["Physician", "Nurse", "PA"],
                                ["Pharmacist", "Dietitian", "Physio"],
                                ["Researcher", "Other"]]

    private var canSubmit: Bool {
        role != nil && (license.filter { !$0.isWhitespace }.count >= 4 || attached)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PepBackChip { model.advanceVerify(to: .intro) }
                .padding(.top, Space.md)

            VerifyTitle(title: "Prove it once",
                        subtitle: "Reviewed by a human, usually within 48 hours. Documents are deleted after review.")
                .padding(.top, Space.x2l)
                .entrance(appeared, delay: 0, blur: false)

            section("YOUR ROLE")
                .padding(.top, Space.x2l)
                .entrance(appeared, delay: 0.1, blur: false)

            VStack(alignment: .leading, spacing: Space.sm) {
                ForEach(Self.roles, id: \.first) { rowRoles in
                    HStack(spacing: Space.sm) {
                        ForEach(rowRoles, id: \.self) { r in chip(r) }
                    }
                }
            }
            .padding(.top, Space.md)
            .entrance(appeared, delay: 0.1, blur: false)

            section("LICENSE / NPI NUMBER")
                .padding(.top, Space.x2l)
                .entrance(appeared, delay: 0.18, blur: false)

            TextField("", text: $license,
                      prompt: Text("e.g. 1234567890").foregroundStyle(Ink.hint))
                .keyboardType(.numbersAndPunctuation)
                .focused($focused)
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 18)
                .frame(height: Metrics.input)
                .background(Fill.regular,
                            in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                .padding(.top, Space.md)
                .entrance(appeared, delay: 0.18, blur: false)

            Button {
                if attached {
                    withAnimation(Motion.select) { attachedName = nil; photoItem = nil }
                } else {
                    showUploadOptions = true
                }
            } label: {
                VStack(spacing: 4) {
                    Text(attached ? "\(attachedName ?? "Credential") attached ✓"
                                  : "Or upload a credential")
                        .pepText(.label, attached ? Accent.success : Ink.primary)
                        .lineLimit(1)
                    Text(attached ? "Tap to remove"
                                  : "Diploma, license, faculty page — PDF or photo")
                        .pepText(.footnote, Ink.tertiary)
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .frame(height: 84)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                        .strokeBorder(attached ? Accent.success : Color.black.opacity(0.16),
                                      style: StrokeStyle(lineWidth: 1.2, dash: [6, 6]))
                )
            }
            .padding(.top, Space.lg)
            .entrance(appeared, delay: 0.24, blur: false)
            .confirmationDialog("Add a credential", isPresented: $showUploadOptions,
                                titleVisibility: .visible) {
                Button("Choose from Photos") { showPhotoPicker = true }
                Button("Choose a file") { showFilePicker = true }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                guard item != nil else { return }
                withAnimation(Motion.select) { attachedName = "Photo" }
            }
            .fileImporter(isPresented: $showFilePicker,
                          allowedContentTypes: [.pdf, .image]) { result in
                if case .success(let url) = result {
                    // TODO: stage the file for the backend review queue
                    withAnimation(Motion.select) { attachedName = url.lastPathComponent }
                }
            }

            Spacer()

            Button("Submit for review") {
                // TODO: upload to the backend review queue
                model.verificationPending = true
                model.advanceVerify(to: .review)
            }
            .buttonStyle(.pepPrimary)
            .disabled(!canSubmit)
            .padding(.bottom, Space.lg)
            .entrance(appeared, delay: 0.3, blur: false)
        }
        .padding(.horizontal, Space.margin)
        .onAppear { appeared = true }
    }

    private func section(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.55)
            .foregroundStyle(Ink.tertiary)
    }

    private func chip(_ r: String) -> some View {
        let selected = role == r
        return Button {
            withAnimation(Motion.select) { role = r }
        } label: {
            Text(r)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? Ink.onDark : Ink.primary)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(selected ? AnyShapeStyle(Fill.charcoal) : AnyShapeStyle(Fill.regular),
                            in: Capsule())
        }
    }
}

// MARK: - Step 3 · in review

private struct VerifyReview: View {
    @Environment(AppModel.self) private var model
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.seal")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.16))
                .entrance(appeared, delay: 0, blur: false)

            Text("We're checking your credentials")
                .pepText(.title)
                .padding(.top, Space.x2l)
                .entrance(appeared, delay: 0.1, blur: false)

            Text("Usually within 48 hours. Use the rally as normal —\nyour badge appears when you're approved.")
                .pepText(.label, Ink.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, Space.md)
                .entrance(appeared, delay: 0.18, blur: false)

            Spacer()

            Button("Done") { model.advanceVerify(to: nil) }
                .buttonStyle(.pepGhost)
                .padding(.bottom, Space.lg)
                .entrance(appeared, delay: 0.26, blur: false)
        }
        .padding(.horizontal, Space.margin)
        .onAppear { appeared = true }
    }
}

#Preview("Intro") {
    VerificationFlow(step: .intro).environment(AppModel())
}
