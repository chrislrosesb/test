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
        ZStack(alignment: .top) {
            // Layer 1: Full-screen blurred background
            backgroundLayer
                .ignoresSafeArea()

            // Layer 2: Scrollable content
            ScrollView {
                VStack(spacing: 0) {
                    // Hero image (top, ~300pt)
                    heroSection

                    // Content cards
                    VStack(spacing: 12) {
                        titleCard
                        readButton
                        ratingAndStatusCard
                        noteCard
                        if currentLink.category != nil || (currentLink.tags != nil && !currentLink.tags!.isEmpty) {
                            metaCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 60)
                }
            }
            .ignoresSafeArea(edges: .top)

            // Layer 3: Floating nav buttons (X + share)
            HStack {
                glassNavButton(icon: "square.and.arrow.up") { shareArticle() }
                Spacer()
                glassNavButton(icon: "xmark") { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
        }
        .sheet(isPresented: $showReader) {
            WebReaderView(url: currentLink.url, title: currentLink.title ?? currentLink.url)
        }
    }

    // MARK: - Background

    @ViewBuilder
    var backgroundLayer: some View {
        if let rawURL = currentLink.image, let imageURL = URL(string: rawURL) {
            AsyncImage(url: imageURL) { phase in
                if case .success(let img) = phase {
                    img.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .blur(radius: 50)
                        .saturation(0.7)
                        .overlay(Color.black.opacity(0.45))
                } else {
                    gradientBackground
                }
            }
        } else {
            gradientBackground
        }
    }

    var gradientBackground: some View {
        LinearGradient(
            colors: domainGradient(for: currentLink.domain).map { $0.opacity(0.8) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(Color.black.opacity(0.4))
    }

    // MARK: - Hero

    @ViewBuilder
    var heroSection: some View {
        if let rawURL = currentLink.image, let imageURL = URL(string: rawURL) {
            AsyncImage(url: imageURL) { phase in
                if case .success(let img) = phase {
                    img.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 300)
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
        ZStack {
            LinearGradient(
                colors: domainGradient(for: currentLink.domain),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let first = currentLink.domain?.first {
                Text(String(first).uppercased())
                    .font(.system(size: 80, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
        .frame(height: 260)
    }

    // MARK: - Title Card

    var titleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let rawFavicon = currentLink.favicon, let faviconURL = URL(string: rawFavicon) {
                    AsyncImage(url: faviconURL) { phase in
                        if case .success(let img) = phase {
                            img.resizable().frame(width: 16, height: 16).clipShape(Circle())
                        }
                    }
                }
                Text(currentLink.domain ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(.primary)

            if let description = currentLink.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Read Button

    var readButton: some View {
        Button {
            showReader = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "book.open.fill")
                Text("Read Article")
                    .fontWeight(.semibold)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background {
                if #available(iOS 26, *) {
                    Capsule().glassEffect(.regular)
                } else {
                    Capsule().fill(Color.accentColor)
                }
            }
        }
    }

    // MARK: - Rating + Status Card

    var ratingAndStatusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Stars
            VStack(alignment: .leading, spacing: 10) {
                Label("Rating", systemImage: "star")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { i in
                        Button {
                            let newStars = currentLink.stars == i ? 0 : i
                            currentLink.stars = newStars
                            Task { await vm.updateStars(link: link, stars: newStars) }
                        } label: {
                            Image(systemName: i <= (currentLink.stars ?? 0) ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(i <= (currentLink.stars ?? 0) ? .yellow : Color(.systemGray3))
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(duration: 0.2, bounce: 0.6), value: currentLink.stars)
                    }
                    Spacer()
                }
            }

            Divider()

            // Status
            VStack(alignment: .leading, spacing: 10) {
                Label("Status", systemImage: "tag")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

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
                                .opacity(currentLink.status == nil || isSelected ? 1 : 0.45)
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(duration: 0.25, bounce: 0.5), value: currentLink.status)
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Note Card

    var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Note", systemImage: "note.text")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

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
            } else {
                Button {
                    isEditingNote = true
                } label: {
                    if let note = currentLink.note, !note.isEmpty {
                        Text(note)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Label("Add a note…", systemImage: "plus.circle")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Meta Card

    var metaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let category = currentLink.category {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Category", systemImage: "folder")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text(category)
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.indigo.opacity(0.15))
                        .foregroundStyle(.indigo)
                        .clipShape(Capsule())
                }
            }

            if let tags = currentLink.tags, !tags.isEmpty {
                if currentLink.category != nil { Divider() }
                VStack(alignment: .leading, spacing: 6) {
                    Label("Tags", systemImage: "tag")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    FlowLayout(tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Floating Nav Buttons

    func glassNavButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background {
                    if #available(iOS 26, *) {
                        Circle().glassEffect(.regular)
                    } else {
                        Circle().fill(.ultraThinMaterial)
                    }
                }
        }
    }

    func shareArticle() {
        guard let url = URL(string: currentLink.url) else { return }
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

// MARK: - Glass Card Modifier

extension View {
    func glassCard() -> some View {
        self.background {
            if #available(iOS 26, *) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .glassEffect(.regular)
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Flow layout for tags

struct FlowLayout: View {
    let tags: [String]

    var body: some View {
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
