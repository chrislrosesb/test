import SwiftUI

struct FinishedReadingSheet: View {
    let link: Link
    let vm: LibraryViewModel
    let onDismiss: () -> Void
    var onReflect: ((Link) -> Void)? = nil

    @State private var quickNote = ""
    @State private var showNote = false
    @State private var saved = false
    @State private var showReflectPrompt = false

    private var store: ReflectionStore { ReflectionStore.shared }

    var body: some View {
        VStack(spacing: 0) {
            if showReflectPrompt {
                reflectPromptView
            } else if saved {
                savedView
            } else if showNote {
                noteView
            } else {
                mainView
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Main view (two big buttons + cancel)

    var mainView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Finished reading?")
                .font(.title3)
                .fontWeight(.bold)

            Text(link.title ?? link.domain ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                // Mark as Done — big green button
                Button {
                    Haptics.success()
                    Task {
                        await vm.updateStatus(link: link, status: "done")
                        withAnimation { saved = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            withAnimation { saved = false; showReflectPrompt = true }
                        }
                    }
                } label: {
                    Label("Mark as Done", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Add a Note — same size, secondary style
                Button {
                    withAnimation(.spring(duration: 0.3)) { showNote = true }
                } label: {
                    Label("Add a Note", systemImage: "note.text")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.bordered)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Cancel
                Button("Cancel") {
                    onDismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Note view

    var noteView: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Add a note")
                .font(.title3)
                .fontWeight(.bold)

            TextEditor(text: $quickNote)
                .frame(minHeight: 100, maxHeight: 160)
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Haptics.success()
                    Task {
                        await vm.updateStatus(link: link, status: "done")
                        if !quickNote.isEmpty {
                            await vm.updateNote(link: link, note: quickNote)
                        }
                        withAnimation { saved = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            withAnimation { saved = false; showReflectPrompt = true }
                        }
                    }
                } label: {
                    Label("Save & Mark Done", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button("Cancel") {
                    onDismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Saved confirmation (brief)

    var savedView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .symbolEffect(.bounce)
            Text("Done!")
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
        }
    }

    // MARK: - Reflect prompt

    var reflectPromptView: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 44))
                    .foregroundStyle(.teal)

                Text("Go deeper?")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("Answer a couple of questions to lock in what you learned.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Depth score preview
            let score = store.depthScore(for: link)
            let afterScore = min(score + 25, 100)
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Depth \(score)")
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("\(afterScore)")
                    .fontWeight(.bold)
                    .foregroundStyle(store.depthColor(score: afterScore))
            }
            .font(.caption)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground), in: Capsule())

            Spacer()

            VStack(spacing: 12) {
                Button {
                    onDismiss()
                    onReflect?(link)
                } label: {
                    Label("Reflect Now", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    store.addToPending(linkId: link.id)
                    onDismiss()
                } label: {
                    Text("Remind me later")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.bordered)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button("Skip") {
                    onDismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}
