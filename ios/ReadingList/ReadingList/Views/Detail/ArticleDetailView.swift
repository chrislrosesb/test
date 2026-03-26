import SwiftUI

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
            }
            .navigationTitle(currentLink.domain ?? "Article")
            .navigationBarTitleDisplayMode(.inline)
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
