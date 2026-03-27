import SwiftUI
import FoundationModels

struct CurateSheetView: View {
    let selectedLinks: [Link]
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var recipients: [Recipient] = []
    @State private var chosenRecipient: Recipient? = nil
    @State private var newName = ""
    @State private var hint = ""
    @State private var generatedMessage = ""
    @State private var phase: Phase = .loading
    @State private var shareURL: String? = nil
    @State private var error: String? = nil

    enum Phase { case loading, recipientPicker, newRecipient, form, generating, preview, saving, success }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .loading:         loadingView
                case .recipientPicker: recipientPickerView
                case .newRecipient:    newRecipientView
                case .form:            formView
                case .generating:      generatingView
                case .preview:         previewView
                case .saving:          savingView
                case .success:
                    if let url = shareURL { successView(url: url) }
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if phase == .success || phase == .loading {
                        EmptyView()
                    } else {
                        Button(backLabel) { handleBack() }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await loadRecipients() }
    }

    private var navTitle: String {
        switch phase {
        case .recipientPicker: return "Who's this for?"
        case .newRecipient:    return "New Person"
        case .success:         return "Done"
        default:               return "Curate Collection"
        }
    }

    private var backLabel: String {
        switch phase {
        case .preview:       return "Back"
        case .form:          return "Back"
        case .newRecipient:  return recipients.isEmpty ? "Cancel" : "Back"
        default:             return "Cancel"
        }
    }

    private func handleBack() {
        switch phase {
        case .preview:
            withAnimation { phase = .form }
        case .form:
            withAnimation { phase = chosenRecipient != nil ? .recipientPicker : .newRecipient }
        case .newRecipient:
            if recipients.isEmpty { onDone(); dismiss() }
            else { withAnimation { phase = .recipientPicker } }
        default:
            onDone(); dismiss()
        }
    }

    // MARK: - Loading

    var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(1.4)
            Text("Loading…").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Recipient Picker

    var recipientPickerView: some View {
        List {
            Section {
                Text("\(selectedLinks.count) article\(selectedLinks.count == 1 ? "" : "s") to add")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !recipients.isEmpty {
                Section("Your people") {
                    ForEach(recipients) { r in
                        Button {
                            chosenRecipient = r
                            withAnimation { phase = .form }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.name)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text("?recipient=\(r.slug)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                Button {
                    chosenRecipient = nil
                    withAnimation { phase = .newRecipient }
                } label: {
                    Label("New Person…", systemImage: "person.badge.plus")
                }
            }
        }
    }

    // MARK: - New Recipient

    var newRecipientView: some View {
        List {
            Section {
                TextField("Name (e.g. Sarah)", text: $newName)
                    .autocorrectionDisabled()
            } header: {
                Text("Who are you curating for?")
            } footer: {
                let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    Text("Their permanent URL: …?recipient=\(slugify(trimmed))")
                        .font(.caption)
                }
            }

            if let error {
                Section {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    withAnimation { phase = .form }
                } label: {
                    HStack {
                        Spacer()
                        Text("Continue").fontWeight(.semibold)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: - Form

    var formView: some View {
        let name = chosenRecipient?.name ?? newName
        return List {
            Section {
                Text("\(selectedLinks.count) article\(selectedLinks.count == 1 ? "" : "s") selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }

            Section {
                TextField("Why these? (e.g. \"she loves AI tools\")", text: $hint, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text("Your hint for the AI")
            } footer: {
                Text("Optional — the AI will also read your notes on each article.")
                    .font(.caption)
            }

            if let error {
                Section {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Section {
                if #available(iOS 26, *) {
                    Button {
                        Task { await generateMessage() }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Personalise with AI", systemImage: "sparkles")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    Button {
                        Task { await saveBatch(enrichedMessage: nil) }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Add to \(name)'s Feed")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        Task { await saveBatch(enrichedMessage: nil) }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Add to \(name)'s Feed", systemImage: "plus.circle.fill")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Generating

    var generatingView: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(1.4)
            Text("Writing your message…").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Preview

    var previewView: some View {
        let name = chosenRecipient?.name ?? newName
        return List {
            Section {
                Text("Here's what \(name) will see:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                TextEditor(text: $generatedMessage)
                    .frame(minHeight: 140)
                    .font(.body)
            } header: {
                Text("Message preview")
            } footer: {
                Text("You can edit this before adding.")
                    .font(.caption)
            }

            Section {
                Button {
                    Task { await generateMessage() }
                } label: {
                    HStack {
                        Spacer()
                        Label("Regenerate", systemImage: "arrow.clockwise")
                        Spacer()
                    }
                }
                .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    Task { await saveBatch(enrichedMessage: generatedMessage) }
                } label: {
                    HStack {
                        Spacer()
                        Label("Add to \(name)'s Feed", systemImage: "plus.circle.fill")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Saving

    var savingView: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(1.4)
            Text("Adding to feed…").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Success

    func successView(url: String) -> some View {
        let name = chosenRecipient?.name ?? newName
        return VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Added to \(name)'s feed!")
                .font(.title3)
                .fontWeight(.bold)

            Text(url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack(spacing: 16) {
                Button {
                    UIPasteboard.general.string = url
                } label: {
                    Label("Copy Link", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    shareURLActivity(url)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 32)

            Button("Done") {
                onDone(); dismiss()
            }
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Load Recipients

    func loadRecipients() async {
        do {
            let fetched = try await SupabaseClient.shared.fetchRecipients()
            recipients = fetched
            withAnimation {
                phase = fetched.isEmpty ? .newRecipient : .recipientPicker
            }
        } catch {
            withAnimation { phase = .newRecipient }
        }
    }

    // MARK: - AI Generation

    @available(iOS 26, *)
    func generateMessage() async {
        withAnimation { phase = .generating }
        error = nil

        let name = chosenRecipient?.name ?? newName

        let articleContext = selectedLinks.map { link -> String in
            var parts = ["• \"\(link.title ?? link.url)\" (\(link.domain ?? ""))"]
            if let note = link.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parts.append("  Your note: \(note.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            if let ft = ArticleFullTextStore.shared.fetch(linkId: link.id), !ft.digest.isEmpty {
                parts.append("  Article digest: \(ft.digest)")
            } else if let summary = link.summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parts.append("  Summary: \(summary.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            return parts.joined(separator: "\n")
        }.joined(separator: "\n\n")

        let recipientLine = name.isEmpty
            ? "The recipient is a friend (no name given)."
            : "The recipient's name is \(name)."

        let hintLine = hint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "No specific reason given — infer it from the article notes and content."
            : "Chris's reason for sharing: \"\(hint.trimmingCharacters(in: .whitespacesAndNewlines))\""

        let prompt = """
        Write a short personal note from Chris Rose to a friend, sharing a curated reading list.

        \(recipientLine)
        \(hintLine)

        Articles Chris selected:
        \(articleContext)

        Write 2–3 short paragraphs in Chris's voice — warm, genuine, like a message you'd send a friend, not a newsletter. First person as Chris. Reference what made him pick these for this specific person, drawing on his notes where possible. End with a brief, casual sign-off. No bullet points. No em dashes. Keep it under 120 words.
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            generatedMessage = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            withAnimation { phase = .preview }
        } catch {
            self.error = "Couldn't generate message — Apple Intelligence may not be available. You can still add the articles without a personalised message."
            withAnimation { phase = .form }
        }
    }

    // MARK: - Save Batch

    func saveBatch(enrichedMessage: String?) async {
        withAnimation { phase = .saving }
        error = nil
        do {
            let recipient: Recipient
            if let existing = chosenRecipient {
                recipient = existing
            } else {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                let slug = slugify(name)
                recipient = try await SupabaseClient.shared.createRecipient(name: name, slug: slug)
                chosenRecipient = recipient
            }

            let ids = selectedLinks.map(\.id)
            try await SupabaseClient.shared.createBatch(
                recipientId: recipient.id,
                linkIds: ids,
                note: hint.isEmpty ? nil : hint,
                enrichedMessage: enrichedMessage
            )

            shareURL = "https://chrislrose.aseva.ai/reading-list.html?recipient=\(recipient.slug)"
            withAnimation { phase = .success }
        } catch {
            self.error = error.localizedDescription
            withAnimation { phase = .form }
        }
    }

    // MARK: - Helpers

    private func slugify(_ name: String) -> String {
        name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    func shareURLActivity(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            var topController = root
            while let presented = topController.presentedViewController {
                topController = presented
            }
            topController.present(av, animated: true)
        }
    }
}
