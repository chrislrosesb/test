import SwiftUI
import FoundationModels

struct CurateSheetView: View {
    let selectedLinks: [Link]
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var recipient = ""
    @State private var hint = ""          // user's rough reason — AI uses this as context
    @State private var generatedMessage = ""
    @State private var phase: Phase = .form
    @State private var shareURL: String? = nil
    @State private var error: String? = nil

    enum Phase { case form, generating, preview, saving, success }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .form:       formView
                case .generating: generatingView
                case .preview:    previewView
                case .saving:     savingView
                case .success:
                    if let url = shareURL { successView(url: url) }
                }
            }
            .navigationTitle("Curate Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if phase == .success {
                        EmptyView()
                    } else {
                        Button(phase == .preview ? "Back" : "Cancel") {
                            if phase == .preview {
                                withAnimation { phase = .form }
                            } else {
                                onDone(); dismiss()
                            }
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Form

    var formView: some View {
        List {
            Section {
                Text("\(selectedLinks.count) article\(selectedLinks.count == 1 ? "" : "s") selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Who is this for?") {
                TextField("Recipient name (e.g. Sarah)", text: $recipient)
                    .autocorrectionDisabled()
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
                } else {
                    Button {
                        Task { await saveCollection(enrichedMessage: nil) }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Create Share Link", systemImage: "link.badge.plus")
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
            ProgressView()
                .scaleEffect(1.4)
            Text("Writing your message…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Preview

    var previewView: some View {
        List {
            Section {
                Text("Here's what \(recipient.isEmpty ? "your friend" : recipient) will see:")
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
                Text("You can edit this before sending.")
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
                    Task { await saveCollection(enrichedMessage: generatedMessage) }
                } label: {
                    HStack {
                        Spacer()
                        Label("Create Share Link", systemImage: "link.badge.plus")
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
            ProgressView()
                .scaleEffect(1.4)
            Text("Creating your collection…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Success

    func successView(url: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Collection Created!")
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

    // MARK: - AI Generation

    @available(iOS 26, *)
    func generateMessage() async {
        withAnimation { phase = .generating }
        error = nil

        let articleContext = selectedLinks.map { link -> String in
            var parts = ["• \"\(link.title ?? link.url)\" (\(link.domain ?? ""))"]
            if let note = link.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parts.append("  Your note: \(note.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            // Use stored digest if available for richer context, otherwise fall back to summary
            if let ft = ArticleFullTextStore.shared.fetch(linkId: link.id), !ft.digest.isEmpty {
                parts.append("  Article digest: \(ft.digest)")
            } else if let summary = link.summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parts.append("  Summary: \(summary.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            return parts.joined(separator: "\n")
        }.joined(separator: "\n\n")

        let recipientLine = recipient.isEmpty
            ? "The recipient is a friend (no name given)."
            : "The recipient's name is \(recipient)."

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
            self.error = "Couldn't generate message — Apple Intelligence may not be available. You can still create the link without a personalised message."
            withAnimation { phase = .form }
        }
    }

    // MARK: - Save

    func saveCollection(enrichedMessage: String?) async {
        withAnimation { phase = .saving }
        error = nil
        do {
            let ids = selectedLinks.map(\.id)
            let collectionId = try await SupabaseClient.shared.createCollection(
                recipient: recipient.isEmpty ? nil : recipient,
                message: hint.isEmpty ? nil : hint,
                enrichedMessage: enrichedMessage,
                linkIds: ids
            )
            shareURL = "https://chrislrose.aseva.ai/c.html?id=\(collectionId)"
            withAnimation { phase = .success }
        } catch {
            self.error = error.localizedDescription
            withAnimation { phase = .preview }
        }
    }

    // MARK: - Share Sheet

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
