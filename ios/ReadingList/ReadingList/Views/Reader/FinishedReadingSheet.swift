import SwiftUI

struct FinishedReadingSheet: View {
    let link: Link
    let vm: LibraryViewModel
    let onDismiss: () -> Void

    @State private var quickNote = ""
    @State private var showNote = false

    var body: some View {
        VStack(spacing: 20) {
            // Big checkmark
            Image(systemName: "checkmark.circle")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .symbolEffect(.bounce)

            Text("Finished reading?")
                .font(.title3)
                .fontWeight(.bold)

            Text(link.title ?? link.domain ?? "this article")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 32)

            if showNote {
                TextField("Quick note (optional)", text: $quickNote, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 24)
            }

            // Actions
            VStack(spacing: 12) {
                Button {
                    Task {
                        await vm.updateStatus(link: link, status: "done")
                        if !quickNote.isEmpty {
                            await vm.updateNote(link: link, note: quickNote)
                        }
                        onDismiss()
                    }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(showNote ? "Save & Mark Done" : "Mark as Done")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if !showNote {
                    Button {
                        withAnimation(.spring(duration: 0.3)) { showNote = true }
                    } label: {
                        Label("Add a note first", systemImage: "note.text")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }

                Button("Not yet") {
                    onDismiss()
                }
                .foregroundStyle(.secondary)
                .font(.subheadline)
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
