import SwiftUI

struct ReflectionView: View {
    let link: Link
    let vm: LibraryViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var engine: ReflectionEngine
    @State private var engineTask: Task<Void, Never>? = nil
    @FocusState private var inputFocused: Bool

    private let store = ReflectionStore.shared
    private var scoreBeforeRef: Int

    init(link: Link, vm: LibraryViewModel) {
        self.link = link
        self.vm = vm
        _engine = State(initialValue: ReflectionEngine(link: link))
        scoreBeforeRef = ReflectionStore.shared.depthScore(for: link)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                articleHeader
                Divider()
                conversationArea
                Divider()
                inputBar
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        engine.inputText = ""
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if case .done = engine.phase {
                        Button("Save & Close") { saveAndClose() }
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.teal)
                    }
                }
            }
        }
        .onAppear {
            engineTask = Task { await engine.start() }
        }
        .onDisappear {
            engineTask?.cancel()
            engineTask = nil
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Article header

    var articleHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.caption)
                        .foregroundStyle(Color.teal)
                    Text("Reflect")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.teal)
                }
                Text(link.title ?? link.domain ?? "Article")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            Spacer()
            depthScoreChip
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    var depthScoreChip: some View {
        let score = store.depthScore(for: link)
        let afterScore = min(score + (store.isReflected(link.id) ? 0 : 25), 100)
        return VStack(spacing: 2) {
            HStack(spacing: 3) {
                Text("\(scoreBeforeRef)")
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text("\(afterScore)")
                    .fontWeight(.bold)
                    .foregroundStyle(store.depthColor(score: afterScore))
            }
            .font(.caption)
            Text("depth")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Conversation

    @ViewBuilder
    var conversationArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(engine.messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }
                    if case .thinking = engine.phase {
                        thinkingBubble
                    }
                    if case .done(let note) = engine.phase {
                        doneCard(note: note)
                    }
                    if case .unavailable(let msg) = engine.phase {
                        unavailableView(msg)
                    }
                    if case .error(let msg) = engine.phase {
                        errorView(msg)
                    }
                    Color.clear.frame(height: 8).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .onChange(of: engine.messages.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom") }
            }
            .onChange(of: engine.phase) { _, _ in
                withAnimation { proxy.scrollTo("bottom") }
            }
        }
    }

    @ViewBuilder
    func messageBubble(_ msg: ReflectionMessage) -> some View {
        HStack {
            if msg.role == .user { Spacer(minLength: 48) }
            Text(msg.text)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    msg.role == .ai
                        ? Color(.secondarySystemBackground)
                        : Color.teal.opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            msg.role == .ai ? Color.clear : Color.teal.opacity(0.3),
                            lineWidth: 1
                        )
                )
                .frame(maxWidth: .infinity, alignment: msg.role == .ai ? .leading : .trailing)
            if msg.role == .ai { Spacer(minLength: 48) }
        }
    }

    var thinkingBubble: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.teal.opacity(0.6))
                        .frame(width: 7, height: 7)
                        .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2), value: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            Spacer(minLength: 48)
        }
    }

    func doneCard(note: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Reflection saved", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.teal)
            Text("This has been added to your note. Tap Save & Close to finish.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.teal.opacity(0.25), lineWidth: 1))
    }

    func unavailableView(_ msg: String) -> some View {
        Label(msg, systemImage: "sparkles.slash")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding()
    }

    func errorView(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(msg).font(.caption).foregroundStyle(.secondary)
            Button("Try Again") { Task { await engine.start() } }
                .font(.caption).tint(Color.teal)
        }
        .padding()
    }

    // MARK: - Input bar

    @ViewBuilder
    var inputBar: some View {
        switch engine.phase {
        case .waitingForAnswer(let exchange):
            HStack(alignment: .bottom, spacing: 10) {
                Text("\(exchange)/2")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 12)

                TextField("Your answer…", text: $engine.inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                    .focused($inputFocused)

                Button {
                    inputFocused = false
                    Task { await engine.submitAnswer() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(engine.inputText.trimmingCharacters(in: .whitespaces).isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.teal))
                }
                .disabled(engine.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .onAppear { inputFocused = true }

        case .done:
            EmptyView()

        default:
            EmptyView()
        }
    }

    // MARK: - Save

    private func saveAndClose() {
        guard case .done(let note) = engine.phase else { return }
        store.markReflected(linkId: link.id)
        Haptics.success()
        dismiss()
        // Fire-and-forget note update — dismiss first so the sheet is gone
        Task { await vm.updateNote(link: link, note: note) }
    }
}
