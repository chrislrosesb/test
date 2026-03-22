import SwiftUI

struct ArticleDetailView: View {
    let link: Link
    @Environment(LibraryViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var editedNote: String = ""
    @State private var isEditingNote = false
    @State private var showReader = false
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
                    // Hero image
                    heroSection

                    VStack(alignment: .leading, spacing: 20) {
                        // Title & domain
                        headerSection

                        Divider()

                        // Stars
                        starSection

                        // Status
                        statusSection

                        Divider()

                        // Note
                        noteSection

                        Divider()

                        // Tags & category
                        metaSection
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showReader) {
                WebReaderView(url: currentLink.url, title: currentLink.title ?? currentLink.url)
            }
        }
    }

    // MARK: - Hero

    @ViewBuilder
    var heroSection: some View {
        if let rawURL = currentLink.image, let imageURL = URL(string: rawURL) {
            AsyncImage(url: imageURL) { phase in
                if case .success(let img) = phase {
                    img.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 240)
                        .clipped()
                } else {
                    fallbackHero
                }
            }
        } else {
            fallbackHero
        }
    }

    var fallbackHero: some View {
        LinearGradient(
            colors: domainGradient(for: currentLink.domain),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: 180)
        .overlay {
            if let first = currentLink.domain?.first {
                Text(String(first).uppercased())
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
    }

    // MARK: - Header

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let rawFavicon = currentLink.favicon, let faviconURL = URL(string: rawFavicon) {
                    AsyncImage(url: faviconURL) { phase in
                        if case .success(let img) = phase {
                            img.resizable().frame(width: 16, height: 16).clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }
                if let domain = currentLink.domain {
                    Text(domain)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let savedAt = currentLink.savedAt {
                    Text(savedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(currentLink.title ?? currentLink.url)
                .font(.title2)
                .fontWeight(.bold)

            if let description = currentLink.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Button {
                showReader = true
            } label: {
                Label("Read Article", systemImage: "book.open")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Stars

    var starSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rating")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)

            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        let newStars = currentLink.stars == i ? 0 : i
                        currentLink.stars = newStars
                        Task { await vm.updateStars(link: link, stars: newStars) }
                    } label: {
                        Image(systemName: i <= (currentLink.stars ?? 0) ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(i <= (currentLink.stars ?? 0) ? .yellow : Color(.systemGray4))
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(duration: 0.2, bounce: 0.5), value: currentLink.stars)
                }
                Spacer()
            }
        }
    }

    // MARK: - Status

    var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)

            HStack(spacing: 8) {
                ForEach(["to-read", "to-try", "to-share", "done"], id: \.self) { status in
                    let isSelected = currentLink.status == status
                    Button {
                        let newStatus = isSelected ? nil : status
                        currentLink.status = newStatus
                        currentLink.read = newStatus == "done"
                        Task { await vm.updateStatus(link: link, status: newStatus) }
                    } label: {
                        StatusPill(status: status)
                            .scaleEffect(isSelected ? 1.08 : 1)
                            .opacity(currentLink.status == nil || isSelected ? 1 : 0.5)
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(duration: 0.25, bounce: 0.5), value: currentLink.status)
                }
            }
        }
    }

    // MARK: - Note

    var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)

            if isEditingNote {
                TextEditor(text: $editedNote)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

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
                .padding(.top, 4)
            } else {
                Button {
                    isEditingNote = true
                } label: {
                    if let note = currentLink.note, !note.isEmpty {
                        Text(note)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add a note…")
                        }
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Meta

    var metaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let category = currentLink.category {
                labeledRow(label: "Category") {
                    Text(category)
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.indigo.opacity(0.12))
                        .foregroundStyle(.indigo)
                        .clipShape(Capsule())
                }
            }

            if let tags = currentLink.tags, !tags.isEmpty {
                labeledRow(label: "Tags") {
                    FlowLayout(tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
                }
            }
        }
    }

    @ViewBuilder
    func labeledRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)
            content()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        ToolbarItem(placement: .topBarLeading) {
            Button {
                guard let url = URL(string: currentLink.url) else { return }
                let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let root = scene.windows.first?.rootViewController {
                    root.present(av, animated: true)
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }
}

// MARK: - Flow layout for tags

struct FlowLayout: View {
    let tags: [String]

    var body: some View {
        // Simple wrapping tag layout
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
            }
        }
    }
}
