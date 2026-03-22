import SwiftUI

struct ArticleDetailView: View {
    let link: Link
    @Environment(LibraryViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var editedNote: String = ""
    @State private var isEditingNote = false
    @State private var showEnrich = false
    @State private var currentLink: Link

    init(link: Link) {
        self.link = link
        self._currentLink = State(initialValue: link)
        self._editedNote = State(initialValue: link.note ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Compact hero — small rounded thumbnail, not giant
                    heroRow
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // Title + domain
                    titleSection
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    // Action buttons
                    actionButtons
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // Rating
                    ratingSection
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    // Status
                    statusSection
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    // Note
                    noteSection
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    // Category + Tags
                    if currentLink.category != nil || hasTagContent {
                        metaSection
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.bottom, 20)
            }
            .background(Color(.systemBackground))
            .navigationTitle(currentLink.domain ?? "Article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            shareArticle()
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            guard let url = URL(string: currentLink.url) else { return }
                            UIApplication.shared.open(url)
                        } label: {
                            Label("Open in Safari", systemImage: "safari")
                        }
                        Button {
                            UIPasteboard.general.string = currentLink.url
                        } label: {
                            Label("Copy URL", systemImage: "doc.on.doc")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showEnrich) {
            EnrichSheetView(link: currentLink) { updatedLink in
                currentLink = updatedLink
            }
            .environment(vm)
        }
    }

    var hasTagContent: Bool {
        if let tags = currentLink.tags { return !tags.isEmpty }
        return false
    }

    // MARK: - Hero Row

    var heroRow: some View {
        HStack(spacing: 14) {
            // Thumbnail
            thumbnailView
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Quick info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    faviconView
                    Text(currentLink.domain ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let savedAt = currentLink.savedAt {
                    Text(savedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if let status = currentLink.status {
                    StatusPill(status: status)
                        .padding(.top, 2)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    var thumbnailView: some View {
        if let rawURL = currentLink.image, let imageURL = URL(string: rawURL) {
            AsyncImage(url: imageURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().aspectRatio(contentMode: .fill)
                } else {
                    fallbackThumbnail
                }
            }
        } else {
            fallbackThumbnail
        }
    }

    var fallbackThumbnail: some View {
        ZStack {
            LinearGradient(colors: domainGradient(for: currentLink.domain),
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if let first = currentLink.domain?.first {
                Text(String(first).uppercased())
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    @ViewBuilder
    var faviconView: some View {
        if let rawFavicon = currentLink.favicon, let faviconURL = URL(string: rawFavicon) {
            AsyncImage(url: faviconURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().frame(width: 14, height: 14).clipShape(Circle())
                }
            }
        }
    }

    // MARK: - Title

    var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(currentLink.title ?? currentLink.url)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let desc = currentLink.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }

    // MARK: - Action Buttons

    var actionButtons: some View {
        Button { showEnrich = true } label: {
            Label("Enrich with AI", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .tint(.purple)
        .buttonStyle(.borderedProminent)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Rating

    var ratingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rating")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        let n = currentLink.stars == i ? 0 : i
                        currentLink.stars = n
                        Task { await vm.updateStars(link: link, stars: n) }
                    } label: {
                        Image(systemName: i <= (currentLink.stars ?? 0) ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundStyle(i <= (currentLink.stars ?? 0) ? .yellow : Color(.systemGray3))
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(duration: 0.2, bounce: 0.6), value: currentLink.stars)
                }
                Spacer()
            }
        }
    }

    // MARK: - Status

    var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                statusButton("to-read")
                statusButton("to-try")
                statusButton("to-share")
                statusButton("done")
            }
        }
    }

    func statusButton(_ status: String) -> some View {
        let isSelected = currentLink.status == status
        return Button {
            let newStatus = isSelected ? nil : status
            currentLink.status = newStatus
            currentLink.read = newStatus == "done"
            Task { await vm.updateStatus(link: link, status: newStatus) }
        } label: {
            StatusPill(status: status)
                .scaleEffect(isSelected ? 1.05 : 1)
                .opacity(currentLink.status == nil || isSelected ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.25, bounce: 0.5), value: currentLink.status)
    }

    // MARK: - Note

    var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Note")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if isEditingNote {
                TextEditor(text: $editedNote)
                    .frame(minHeight: 80)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .scrollContentBackground(.hidden)
                HStack {
                    Button("Cancel") {
                        editedNote = currentLink.note ?? ""
                        isEditingNote = false
                    }
                    .foregroundStyle(.secondary)
                    Spacer()
                    Button("Save") {
                        currentLink.note = editedNote.isEmpty ? nil : editedNote
                        isEditingNote = false
                        Task { await vm.updateNote(link: link, note: editedNote) }
                    }
                    .fontWeight(.semibold)
                }
            } else {
                Button { isEditingNote = true } label: {
                    Group {
                        if let note = currentLink.note, !note.isEmpty {
                            Text(note)
                                .font(.body)
                                .foregroundStyle(.primary)
                        } else {
                            Label("Add a note…", systemImage: "plus.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Meta (Category + Tags)

    var metaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let category = currentLink.category {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(category)
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.indigo.opacity(0.15))
                        .foregroundStyle(.indigo)
                        .clipShape(Capsule())
                }
            }

            if let tags = currentLink.tags, !tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    FlowLayout(tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
                }
            }
        }
    }

    // MARK: - Helpers

    func shareArticle() {
        guard let url = URL(string: currentLink.url) else { return }
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

// MARK: - Material Card modifier

extension View {
    func materialCard() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(white: 0.14).opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
    }

    func glassCard() -> some View { materialCard() }
}

// MARK: - Flow layout

struct FlowLayout: View {
    let tags: [String]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag).font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
            }
        }
    }
}
