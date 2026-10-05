import SwiftUI
import PhotosUI

/// The composer, Coinbase-order anatomy: the question IS the amount —
/// giant type up top, a "reaches 2.1k members" conversion line, then
/// Topic and Attach as chevron rows, and one big Post button. Ask/Poll
/// switch like Buy/Sell.
struct ComposeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var onPost: (FeedQuestion) -> Void

    @State private var text = ""
    @State private var selectedTopic = FeedTopics.all[0].name
    @State private var appeared = false

    // attachments
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var photoAttached = false
    @State private var gifAttached = false
    @State private var showGifSearch = false
    @State private var showSourceField = false
    @State private var link = ""
    @State private var sourceFileName: String?
    @State private var showFileImporter = false
    @State private var pollOptions: [String]?

    @FocusState private var focused: Bool

    private var canPost: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    enum Mode: String, CaseIterable { case ask = "Ask", poll = "Poll" }
    @State private var mode: Mode = .ask

    /// the question stays poster-size while short, settling as it grows
    private var questionSize: CGFloat {
        switch text.count {
        case ..<50:   return 32
        case ..<120:  return 24
        default:      return 18
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // nav — back only, like the order screen
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Ink.primary)
                        .frame(width: 44, height: 44, alignment: .leading)
                }
                Spacer()
            }
            .padding(.horizontal, Space.xl)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Ask | Poll — Buy/Sell's segmented pill
                    HStack(spacing: 0) {
                        ForEach(Mode.allCases, id: \.self) { m in
                            Button {
                                withAnimation(Motion.select) {
                                    mode = m
                                    pollOptions = m == .poll ? (pollOptions ?? ["", ""]) : nil
                                }
                            } label: {
                                Text(m.rawValue)
                                    .font(.system(size: 15, weight: .semibold))
                                    .tracking(-0.15)
                                    .foregroundStyle(mode == m ? Ink.onDark : Ink.primary)
                                    .padding(.horizontal, 22)
                                    .frame(height: 40)
                                    .background(mode == m ? AnyShapeStyle(Fill.charcoal)
                                                          : AnyShapeStyle(Color.clear),
                                                in: Capsule())
                            }
                        }
                    }
                    .padding(4)
                    .background(Fill.regular, in: Capsule())
                    .padding(.top, Space.sm)

                    // the amount: your question, giant
                    TextField("", text: $text,
                              prompt: Text(mode == .poll ? "What should the rally vote on?"
                                                         : "Ask anything")
                                  .foregroundStyle(Color.black.opacity(0.18)),
                              axis: .vertical)
                        .font(.system(size: questionSize, weight: .bold))
                        .tracking(questionSize > 24 ? -0.96 : -0.36)
                        .foregroundStyle(Ink.primary)
                        .focused($focused)
                        .lineLimit(1...6)
                        .padding(.top, 30)

                    // the conversion line
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 11, weight: .semibold))
                        Text("reaches 2.1k members")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(-0.13)
                    }
                    .foregroundStyle(Ink.tertiary)
                    .padding(.top, 12)

                    if mode == .poll, pollOptions != nil {
                        pollEditor
                            .padding(.top, Space.x2l)
                    }

                    // attached chips
                    if photoAttached || gifAttached || sourceFileName != nil || showSourceField {
                        VStack(alignment: .leading, spacing: Space.sm) {
                            if photoAttached { attachmentChip("photo.on.rectangle", "Photo attached") { photoAttached = false; photoItem = nil } }
                            if gifAttached { attachmentChip("photo.stack", "GIF attached") { gifAttached = false } }
                            if let name = sourceFileName {
                                attachmentChip("doc.text", "\(name) attached") { sourceFileName = nil }
                            }
                            if showSourceField { sourceBlock }
                        }
                        .padding(.top, Space.x2l)
                    }

                    // the one order row — Topic, "where does this go"
                    Menu {
                        ForEach(FeedTopics.all, id: \.name) { t in
                            Button(t.name) {
                                withAnimation(Motion.select) { selectedTopic = t.name }
                            }
                        }
                    } label: {
                        orderRow(iconText: String(selectedTopic.prefix(1)),
                                 iconHex: FeedTopics.hex(for: selectedTopic),
                                 title: "Topic", subtitle: "Where it lives",
                                 value: selectedTopic)
                    }
                    .padding(.top, Space.x3l)
                }
                .padding(.horizontal, Space.xl)
            }
            .scrollIndicators(.hidden)

            // attach toolbar — familiar composer icons, above the button
            HStack(spacing: 8) {
                attachTool("photo", active: photoAttached) { showPhotoPicker = true }
                attachTool("face.smiling", active: gifAttached) { showGifSearch = true }
                attachTool("chart.bar", active: pollOptions != nil) {
                    withAnimation(Motion.select) {
                        if mode == .poll { mode = .ask; pollOptions = nil }
                        else { mode = .poll; pollOptions = ["", ""] }
                    }
                }
                attachTool("link", active: showSourceField || sourceFileName != nil) {
                    withAnimation(Motion.select) { showSourceField.toggle() }
                }
                Spacer()
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.sm)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.black.opacity(0.06)).frame(height: 0.7)
            }

            // the one big action — style lives on the LABEL so the whole
            // capsule is the tap target (styling the Button itself leaves only
            // the "Post" text tappable — the reason this never fired)
            Button { post() } label: {
                Text("Post")
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.32)
                    .foregroundStyle(canPost ? Ink.onDark : Ink.hint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canPost ? AnyShapeStyle(Fill.charcoal)
                                        : AnyShapeStyle(Color.black.opacity(0.05)),
                                in: Capsule())
                    .contentShape(Capsule())
            }
            .disabled(!canPost)
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.md)
        }
        .background(Color.white.ignoresSafeArea())
        .tint(Ink.secondary)
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .any(of: [.images, .not(.videos)]))
        .onChange(of: photoItem) { _, item in
            guard item != nil else { return }
            withAnimation(Motion.select) { photoAttached = true }
        }
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [.pdf, .image]) { result in
            if case .success(let url) = result {
                // TODO: stage the document for upload
                withAnimation(Motion.select) {
                    sourceFileName = url.lastPathComponent
                    showSourceField = false
                }
            }
        }
        .sheet(isPresented: $showGifSearch) {
            GifSearchSheet {
                withAnimation(Motion.select) { gifAttached = true }
            }
        }
        .onAppear {
            appeared = true
            Task {
                try? await Task.sleep(for: .seconds(0.4))
                focused = true
            }
        }
    }

    // MARK: pieces

    /// A composer attach icon — 44pt tap target, ink when active.
    private func attachTool(_ symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(active ? Ink.primary : Ink.tertiary)
                .frame(width: 44, height: 44)
        }
    }

    /// A Coinbase order row: icon circle, bold title + gray subtitle,
    /// value and chevron on the right.
    private func orderRow(iconText: String? = nil, iconHex: UInt = 0,
                          systemIcon: String? = nil,
                          title: String, subtitle: String,
                          value: String?) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Fill.subtle)
                if let iconText {
                    Text(iconText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Ink.primary)
                }
                if let systemIcon {
                    Image(systemName: systemIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Ink.primary)
                }
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.16)
                    .foregroundStyle(Ink.primary)
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .tracking(-0.14)
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.15)
                    .foregroundStyle(Ink.primary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Ink.tertiary)
        }
        .contentShape(Rectangle())
    }

    private func attachmentChip(_ symbol: String, _ label: String, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundStyle(Ink.secondary)
            Text(label).pepText(.footnote, Ink.primary)
            Button {
                withAnimation(Motion.select) { remove() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(Fill.subtle, in: Capsule())
    }

    private var sourceBlock: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            TextField("", text: $link,
                      prompt: Text("Link a source — study, article, your work").foregroundStyle(Ink.hint))
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Fill.regular,
                            in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))

            Button("Or attach a file — lab work, PDF") { showFileImporter = true }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Ink.secondary)
        }
    }

    private var pollEditor: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            ForEach((pollOptions ?? []).indices, id: \.self) { i in
                TextField("", text: Binding(
                    get: { pollOptions?[i] ?? "" },
                    set: { pollOptions?[i] = $0 }
                ), prompt: Text("Option \(i + 1)").foregroundStyle(Ink.hint))
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(Fill.regular,
                                in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            }
            if (pollOptions?.count ?? 0) < 4 {
                Button("Add option") {
                    withAnimation(Motion.select) { pollOptions?.append("") }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Ink.secondary)
            }
        }
    }

    private func post() {
        guard canPost else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        focused = false
        // TODO: send to the backend; local-only for now
        var extras: [String] = []
        if let poll = pollOptions {
            extras.append("Poll · \(poll.filter { !$0.isEmpty }.count) options")
        }
        if photoAttached { extras.append("Photo") }
        if gifAttached { extras.append("GIF") }
        if let name = sourceFileName { extras.append(name) }
        if !link.isEmpty { extras.append(link) }

        let q = FeedQuestion(
            id: "temp-\(UUID().uuidString)",
            topic: selectedTopic,
            hex: FeedTopics.hex(for: selectedTopic),
            time: "now",
            title: text.trimmingCharacters(in: .whitespacesAndNewlines),
            preview: extras.joined(separator: " · "),
            author: model.handle.isEmpty ? "you" : "@\(model.handle)",
            initials: "JP",
            avatarHex: 0xDFDFDF,
            badge: nil,
            answers: 0,
            isMine: true
        )
        onPost(q)
        dismiss()
    }
}

/// GIF search — the Messages-style grid. There's no public Apple GIF
/// API, so results are placeholder tiles until Tenor/GIPHY is wired;
/// the search, grid, and pick flow are real.
struct GifSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onPick: () -> Void

    @State private var query = ""
    @FocusState private var focused: Bool

    private let tiles: [UInt] = [0xE9E9E9, 0xDFDFDF, 0xEBEBEB, 0xEAEAEA,
                                 0xE8E8E8, 0xD8D8D8, 0xE9E9E9, 0xDFDFDF,
                                 0xEBEBEB, 0xD8D8D8, 0xEAEAEA, 0xE8E8E8]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(Ink.tertiary)
                TextField("", text: $query,
                          prompt: Text("Search GIFs").foregroundStyle(Ink.hint))
                    .font(.system(size: 15, weight: .medium))
                    .focused($focused)
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Fill.regular, in: Capsule())
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.lg)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 4),
                                    GridItem(.flexible(), spacing: 4),
                                    GridItem(.flexible(), spacing: 4)], spacing: 4) {
                    ForEach(tiles.indices, id: \.self) { i in
                        Button {
                            // TODO: attach the actual GIF once Tenor is wired
                            onPick()
                            dismiss()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(hex: tiles[i]).opacity(0.7))
                                    .frame(height: 96)
                                Text("GIF")
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(0.55)
                                    .foregroundStyle(Ink.tertiary)
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.lg)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.white)
        .tint(Ink.secondary)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            Task {
                try? await Task.sleep(for: .seconds(0.3))
                focused = true
            }
        }
    }
}

#Preview {
    ComposeView { _ in }.environment(AppModel())
}
