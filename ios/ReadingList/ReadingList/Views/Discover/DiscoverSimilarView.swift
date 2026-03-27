import SwiftUI

struct DiscoverSimilarView: View {
    @Environment(LibraryViewModel.self) private var vm
    let recap: String
    @Environment(\.dismiss) var dismiss
    @State private var selectedResult: DiscoverResult? = nil
    @State private var addedIds: Set<String> = []

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            Task { await vm.discoverSimilar(fromRecap: recap) }
        }
        .onDisappear {
            vm.clearDiscoverSimilar()
        }
    }

    // MARK: - Sidebar (story list)

    var sidebar: some View {
        Group {
            switch vm.discoverPhase {
            case .idle, .extracting, .searching:
                loadingList
            case .ready(let results):
                storyList(results)
            case .error(let error):
                errorView(error)
            }
        }
        .navigationTitle("Discover Similar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if case .searching = vm.discoverPhase {
                    ProgressView().scaleEffect(0.8)
                } else if case .ready = vm.discoverPhase {
                    Button {
                        Task { await vm.discoverSimilar(fromRecap: recap) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    var loadingList: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text(loadingMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !vm.discoverThemes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(vm.discoverThemes, id: \.self) { theme in
                            Text(theme)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.secondary.opacity(0.15))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            Spacer()
        }
    }

    var loadingMessage: String {
        switch vm.discoverPhase {
        case .extracting: return "Extracting themes from your notes…"
        case .searching:  return "Searching for similar articles…"
        default:          return "Starting search…"
        }
    }

    func storyList(_ results: [DiscoverResult]) -> some View {
        List(results, selection: $selectedResult) { result in
            storyRow(result)
                .tag(result)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        }
        .listStyle(.plain)
    }

    func storyRow(_ result: DiscoverResult) -> some View {
        HStack(spacing: 10) {
            // Domain initial icon
            ZStack {
                LinearGradient(colors: domainGradient(for: result.source), startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(String((result.source.first ?? "W")).uppercased())
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text(result.source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if addedIds.contains(result.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                if !result.snippet.isEmpty {
                    Text(result.snippet)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .contentShape(Rectangle())
    }

    func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Search failed")
                .font(.headline)
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                Task { await vm.discoverSimilar(fromRecap: recap) }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    // MARK: - Detail pane (web reader)

    @ViewBuilder
    var detailPane: some View {
        if let result = selectedResult, let url = URL(string: result.url) {
            WebView(url: url)
                .id(result.id)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(result.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            if !addedIds.contains(result.id) {
                                addedIds.insert(result.id)
                                Task { await vm.addDiscoveredArticle(result) }
                            }
                        } label: {
                            if addedIds.contains(result.id) {
                                Label("Saved", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Label("Add to Reading List", systemImage: "plus.circle")
                            }
                        }
                        .disabled(addedIds.contains(result.id))
                    }
                }
        } else {
            ContentUnavailableView(
                "Select an article",
                systemImage: "newspaper",
                description: Text("Pick a story from the list to read it here")
            )
        }
    }
}

// Simple horizontal wrapping layout for theme tags
struct Wrap: View {
    let themes: [String]
    let spacing: CGFloat

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(themes, id: \.self) { theme in
                Text(theme)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
        }
    }
}

#Preview {
    DiscoverSimilarView(recap: "You are interested in AI, machine learning, and LLMs.")
        .environment(LibraryViewModel())
}
