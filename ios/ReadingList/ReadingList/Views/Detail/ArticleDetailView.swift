import SwiftUI

private enum DeepSavePhase {
    case notSaved
    case saving
    case saved(wordCount: Int, date: Date)
    case digestSynced   // digest available from another device via Supabase, no local raw text
    case error(String)
}

struct ArticleDetailView: View {
    let link: Link
    @Environment(LibraryViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var currentLink: Link
    @State private var editedTitle: String
    @State private var isEditingTitle = false
    @State private var editedTags: String
    @State private var isEditingTags = false
    @State private var editedNote: String
    @State private var isEditingNote = false
    @FocusState private var noteEditorFocused: Bool
    @State private var deepSavePhase: DeepSavePhase = .notSaved
    @State private var showReflect = false

    private var store: ReflectionStore { ReflectionStore.shared }

    init(link: Link) {
        self.link = link
        self._currentLink = State(initialValue: link)
        self._editedTitle = State(initialValue: link.title ?? "")
        self._editedTags = State(initialValue: link.tags ?? "")
        self._editedNote = State(initialValue: link.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Title + Meta
                Section {
                    titleRow
                    HStack(spacing: 6) {
                        if let domain = currentLink.domain {
                            Text(domain)
                                .foregroundStyle(.secondary)
                        }
                        if let savedAt = currentLink.savedAt {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(savedAt.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .font(.subheadline)
                    .listRowSeparator(.hidden)
                }

                // MARK: Status + Category
                Section {
                    // Status row
                    HStack {
                        Text("Status")
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)
                        HStack(spacing: 10) {
                            statusPill("to-read")
                            statusPill("to-try")
                            statusPill("done")
                        }
                    }

                    // Category row
                    HStack {
                        Text("Category")
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)
                        Menu {
                            Button("None") {
                                currentLink.category = nil
                                Task { await vm.updateCategory(link: link, category: nil) }
                            }
                            ForEach(vm.categories) { cat in
                                Button(cat.name) {
                                    currentLink.category = cat.name
                                    Task { await vm.updateCategory(link: link, category: cat.name) }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(currentLink.category ?? "None")
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.indigo.opacity(0.15))
                            .foregroundStyle(.indigo)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // MARK: Rating
                Section {
                    HStack {
                        Text("Rating")
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { i in
                                Button {
                                    let n = currentLink.stars == i ? 0 : i
                                    currentLink.stars = n
                                    Haptics.tap()
                                    Task { await vm.updateStars(link: link, stars: n) }
                                    // Auto-save full text when rating 5 stars
                                    if n == 5,
                                       ArticleFullTextStore.shared.fetch(linkId: currentLink.id) == nil {
                                        Task { await performDeepSave() }
                                    }
                                } label: {
                                    Image(systemName: i <= (currentLink.stars ?? 0) ? "star.fill" : "star")
                                        .font(.title2)
                                        .foregroundStyle(i <= (currentLink.stars ?? 0) ? .yellow : Color(.systemGray3))
                                }
                                .buttonStyle(.plain)
                                .animation(.spring(duration: 0.2, bounce: 0.6), value: currentLink.stars)
                            }
                        }
                    }
                }

                // MARK: Tags
                Section("Tags") {
                    tagsRow
                }

                // MARK: AI Summary
                if let summary = currentLink.summary, !summary.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("AI Summary", systemImage: "sparkles")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.purple)
                            Text(summary)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: Note
                Section("Note") {
                    noteRow
                }

                // MARK: Reflect
                Section {
                    reflectRow
                }

                // MARK: Full Text (on-device)
                Section {
                    deepSaveRow
                } header: {
                    Text("Full Text")
                } footer: {
                    Text("Saves the article text on-device for richer Knowledge Synthesis. Not uploaded anywhere.")
                }
            }
            .navigationTitle(currentLink.domain ?? "Article")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if let existing = ArticleFullTextStore.shared.fetch(linkId: currentLink.id) {
                    deepSavePhase = .saved(wordCount: existing.wordCount, date: existing.fetchedAt)
                } else if let d = currentLink.digest, !d.isEmpty {
                    deepSavePhase = .digestSynced
                }
            }
            .sheet(isPresented: $showReflect) {
                ReflectionView(link: currentLink, vm: vm)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { shareArticle() } label: {
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
    }

    // MARK: - Title Row

    @ViewBuilder
    var titleRow: some View {
        if isEditingTitle {
            TextField("Title", text: $editedTitle, axis: .vertical)
                .font(.headline)
            HStack {
                Button("Cancel") {
                    editedTitle = currentLink.title ?? ""
                    isEditingTitle = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Spacer()
                Button("Save") {
                    let trimmed = editedTitle.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        currentLink.title = trimmed
                        Task { await vm.updateTitle(link: link, title: trimmed) }
                    }
                    isEditingTitle = false
                }
                .buttonStyle(.plain)
                .fontWeight(.semibold)
            }
            .font(.subheadline)
        } else {
            Button {
                editedTitle = currentLink.title ?? ""
                isEditingTitle = true
            } label: {
                Text(currentLink.title ?? currentLink.url)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Status Pill

    func statusPill(_ status: String) -> some View {
        let isSelected = currentLink.status == status
        let label: String = switch status {
        case "to-read": "Read"
        case "to-try": "Do"
        case "done": "Done"
        default: status
        }
        let color: Color = switch status {
        case "to-read": .blue
        case "to-try": .orange
        case "done": .green
        default: .gray
        }
        return Button {
            let newStatus = isSelected ? nil : status
            currentLink.status = newStatus
            currentLink.read = newStatus == "done"
            Haptics.statusChange()
            Task { await vm.updateStatus(link: link, status: newStatus) }
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? color.opacity(0.2) : Color(.systemGray5))
                .foregroundStyle(isSelected ? color : .secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.25, bounce: 0.5), value: currentLink.status)
    }

    // MARK: - Tags Row

    @ViewBuilder
    var tagsRow: some View {
        if isEditingTags {
            TextField("ai, tools, design, swift…", text: $editedTags, axis: .vertical)
                .font(.body)
            Text("Comma-separated · saved as lowercase")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            HStack {
                Button("Cancel") {
                    editedTags = currentLink.tags ?? ""
                    isEditingTags = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Spacer()
                Button("Save") {
                    let cleaned = editedTags
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                        .filter { !$0.isEmpty }
                        .joined(separator: ", ")
                    currentLink.tags = cleaned.isEmpty ? nil : cleaned
                    isEditingTags = false
                    Task { await vm.updateTags(link: link, tags: cleaned.isEmpty ? nil : cleaned) }
                }
                .buttonStyle(.plain)
                .fontWeight(.semibold)
            }
            .font(.subheadline)
        } else {
            Button {
                editedTags = currentLink.tags ?? ""
                isEditingTags = true
            } label: {
                if let tags = currentLink.tags, !tags.isEmpty {
                    Text(tags)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Label("Add tags…", systemImage: "plus.circle")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Note Row

    @ViewBuilder
    var noteRow: some View {
        if isEditingNote {
            TextEditor(text: $editedNote)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .focused($noteEditorFocused)
            HStack {
                Button("Cancel") {
                    noteEditorFocused = false
                    editedNote = currentLink.note ?? ""
                    isEditingNote = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Spacer()
                Button("Save") {
                    noteEditorFocused = false
                    currentLink.note = editedNote.isEmpty ? nil : editedNote
                    isEditingNote = false
                    Task { await vm.updateNote(link: link, note: editedNote) }
                    // Auto-save full text when adding a note for the first time
                    let trimmed = editedNote.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty,
                       ArticleFullTextStore.shared.fetch(linkId: currentLink.id) == nil {
                        Task { await performDeepSave() }
                    }
                }
                .buttonStyle(.plain)
                .fontWeight(.semibold)
            }
            .font(.subheadline)
        } else {
            Button {
                editedNote = currentLink.note ?? ""
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

    // MARK: - Reflect Row

    var reflectRow: some View {
        let score = store.depthScore(for: currentLink)
        let reflected = store.isReflected(currentLink.id)
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray4), lineWidth: 2.5)
                    .frame(width: 32, height: 32)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(store.depthColor(score: score),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 32, height: 32)
                Text("\(score)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(store.depthColor(score: score))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(reflected ? "Reflected" : "Reflect on this article")
                    .font(.body)
                    .foregroundStyle(reflected ? .secondary : .primary)
                Text("Depth score \(score)/100")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !reflected {
                Button("Start") { showReflect = true }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.teal)
                    .controlSize(.small)
                    .buttonStyle(.plain)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.teal)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Deep Save Row

    @ViewBuilder
    var deepSaveRow: some View {
        switch deepSavePhase {
        case .notSaved:
            Button {
                Task { await performDeepSave() }
            } label: {
                Label("Save Full Text", systemImage: "doc.text")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.indigo)

        case .saving:
            HStack(spacing: 10) {
                ProgressView().scaleEffect(0.8)
                Text("Fetching article…")
                    .foregroundStyle(.secondary)
            }

        case .saved(let wordCount, let date):
            VStack(alignment: .leading, spacing: 6) {
                Label("Full text saved", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .fontWeight(.medium)
                Text("\(wordCount) words · \(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                HStack(spacing: 20) {
                    Button("Re-fetch") { Task { await performDeepSave() } }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Button("Delete Saved Text") {
                        ArticleFullTextStore.shared.delete(linkId: currentLink.id)
                        deepSavePhase = .notSaved
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .font(.subheadline)
                }
            }

        case .digestSynced:
            VStack(alignment: .leading, spacing: 6) {
                Label("Digest synced from another device", systemImage: "arrow.trianglehead.2.clockwise.rotate.90.circle.fill")
                    .foregroundStyle(.teal)
                    .fontWeight(.medium)
                Text("AI digest is available for podcast generation. Save full text here to enable Knowledge Synthesis on this device.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Button("Save Full Text on This Device") {
                    Task { await performDeepSave() }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.indigo)
                .font(.subheadline)
            }

        case .error(let msg):
            VStack(alignment: .leading, spacing: 6) {
                Label("Save failed", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Try Again") { Task { await performDeepSave() } }
                    .buttonStyle(.plain)
                    .foregroundStyle(.indigo)
                    .font(.subheadline)
            }
        }
    }

    func performDeepSave() async {
        deepSavePhase = .saving
        do {
            let rawText = try await ArticleExtractor.extract(from: currentLink.url)
            let wordCount = rawText.split(separator: " ").count

            var digest = ""
            if #available(iOS 26, *) {
                #if canImport(FoundationModels)
                digest = (try? await ArticleDigestEngine.generateDigest(
                    for: currentLink, rawText: rawText
                )) ?? ""
                #endif
            }

            ArticleFullTextStore.shared.save(
                linkId: currentLink.id,
                rawText: rawText,
                digest: digest,
                wordCount: wordCount
            )
            deepSavePhase = .saved(wordCount: wordCount, date: Date())
        } catch {
            deepSavePhase = .error(error.localizedDescription)
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

// MARK: - Material Card modifier (kept for other views that use it)

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

// MARK: - Flow layout (kept for other views that use it)

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
