import SwiftUI

struct SearchView: View {
    @Environment(LibraryViewModel.self) private var vm
    @State private var selectedLink: Link? = nil
    @State private var useAISearch = false
    @State private var aiQuery = ""
    @State private var isSearching = false

    var displayedLinks: [Link] {
        if useAISearch, let results = vm.aiSearchResults {
            return results
        }
        return vm.filteredLinks
    }

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            Group {
                if useAISearch {
                    aiSearchBody
                } else {
                    keywordSearchBody
                }
            }
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            useAISearch.toggle()
                            vm.clearAISearch()
                            if !useAISearch {
                                aiQuery = ""
                            }
                        }
                    } label: {
                        Image(systemName: useAISearch ? "sparkles" : "sparkle")
                            .foregroundStyle(useAISearch ? Color.purple : Color.primary)
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedLink) { link in
            if let idx = displayedLinks.firstIndex(where: { $0.id == link.id }) {
                ArticleReaderContainer(links: displayedLinks, initialIndex: idx, vm: vm)
            }
        }
    }

    // MARK: - Keyword Search

    var keywordSearchBody: some View {
        @Bindable var vm = vm
        return Group {
            if vm.searchQuery.isEmpty {
                searchPlaceholder
            } else if vm.filteredLinks.isEmpty {
                ContentUnavailableView.search(text: vm.searchQuery)
            } else {
                resultsList(links: vm.filteredLinks)
            }
        }
        .searchable(text: $vm.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search articles…")
    }

    // MARK: - AI Search

    var aiSearchBody: some View {
        VStack(spacing: 0) {
            // Custom search bar for AI
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                TextField("Ask AI…", text: $aiQuery)
                    .textFieldStyle(.plain)
                    .onSubmit { Task { await runAISearch() } }
                if !aiQuery.isEmpty {
                    Button { aiQuery = ""; vm.clearAISearch() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Results
            if isSearching {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Searching with AI…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let results = vm.aiSearchResults {
                if results.isEmpty {
                    ContentUnavailableView("No matches", systemImage: "sparkles", description: Text("AI couldn't find articles matching your query."))
                } else {
                    resultsList(links: results)
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundStyle(.purple.opacity(0.5))
                    Text("Try: \"articles about design\" or \"unread tutorials\"")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Shared Results List

    func resultsList(links: [Link]) -> some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(links) { link in
                    ArticleCardView(link: link)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedLink = link }
                }
            }
            .padding(.vertical, 12)
            .padding(.bottom, 80)
        }
    }

    // MARK: - Placeholder

    var searchPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Search your library")
                .font(.title3)
                .fontWeight(.medium)
            Text("Search across titles, notes, tags, domains, and categories")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Run AI Search

    func runAISearch() async {
        guard !aiQuery.isEmpty else { return }
        isSearching = true
        if #available(iOS 26, *) {
            await vm.aiSearch(query: aiQuery)
        }
        isSearching = false
    }
}
