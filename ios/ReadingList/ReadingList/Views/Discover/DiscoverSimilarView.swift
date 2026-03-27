import SwiftUI

struct DiscoverSimilarView: View {
    @Environment(LibraryViewModel.self) private var vm
    let recap: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                switch vm.discoverPhase {
                case .idle:
                    idleView
                case .extracting, .searching:
                    searchingView
                case .ready(let results):
                    resultsView(results)
                case .error(let error):
                    errorStateView(error)
                }
            }
            .navigationTitle("Similar Articles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            Task { await vm.discoverSimilar(fromRecap: recap) }
        }
        .onDisappear {
            vm.clearDiscoverSimilar()
        }
    }

    var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Ready to search")
                .font(.headline)
            Text("Tap 'Start Search' to find similar articles on the internet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                Task { await vm.discoverSimilar(fromRecap: recap) }
            } label: {
                Label("Start Search", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    var searchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Searching the internet…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !vm.discoverThemes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Themes")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Wrap(spacing: 8) {
                        ForEach(vm.discoverThemes, id: \.self) { theme in
                            Text(theme)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.secondary.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(8)
            }
            Spacer()
        }
        .padding()
    }

    func resultsView(_ results: [DiscoverResult]) -> some View {
        VStack(spacing: 0) {
            List {
                ForEach(results) { result in
                    resultRow(result)
                }
            }
            .listStyle(.plain)
        }
    }

    func resultRow(_ result: DiscoverResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Image/Icon
                if let imageUrl = result.image, let url = URL(string: imageUrl) {
                    CachedAsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        fallbackIcon(result)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    fallbackIcon(result)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)

                    Text(result.source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text(result.snippet)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Button {
                    guard let url = URL(string: result.url) else { return }
                    UIApplication.shared.open(url)
                } label: {
                    Label("Read", systemImage: "safari")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await vm.addDiscoveredArticle(result) }
                    dismiss()
                } label: {
                    Label("Add to Library", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
        }
        .padding(.vertical, 8)
    }

    func fallbackIcon(_ result: DiscoverResult) -> some View {
        ZStack {
            LinearGradient(colors: domainGradient(for: result.source), startPoint: .topLeading, endPoint: .bottomTrailing)
            if let first = result.source.first {
                Text(String(first).uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    func errorStateView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Search failed")
                .font(.headline)
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                Task { await vm.discoverSimilar(fromRecap: recap) }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// Simple wrapping layout for themes
struct Wrap<Content: View>: View {
    let spacing: CGFloat
    let content: [Content]

    init(spacing: CGFloat = 8, @ViewBuilder _ content: @escaping () -> [Content]) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            var line: [Content] = []
            var lineWidth: CGFloat = 0

            ForEach(0..<content.count, id: \.self) { i in
                let item = content[i]
                HStack(spacing: spacing) {
                    ForEach(0..<line.count, id: \.self) { j in
                        line[j]
                    }
                }
            }
        }
    }
}

#Preview {
    DiscoverSimilarView(recap: "You are interested in AI, machine learning, and LLMs.")
        .environment(LibraryViewModel())
}
