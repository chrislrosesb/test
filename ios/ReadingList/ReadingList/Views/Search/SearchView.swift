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
                    aiSearchContent
                } else if vm.searchQuery.isEmpty {
                    searchPlaceholder
                } else if vm.filteredLinks.isEmpty {
                    ContentUnavailableView.search(text: vm.searchQuery)
                } else {
                    searchResultsList(links: vm.filteredLinks)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $vm.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: useAISearch ? "Ask AI…" : "Search articles…")
            .onSubmit(of: .search) {
                if useAISearch {
                    aiQuery = vm.searchQuery
                    Task { await runAISearch() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        useAISearch.toggle()
                        vm.clearAISearch()
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

    // MARK: - AI Search Content

    var aiSearchContent: some View {
        Group {
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
                    searchResultsList(links: results)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(.purple)
                    Text("AI Search")
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("Ask naturally: \"articles about design I haven't read\" or \"tutorials from this week\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Results List

    func searchResultsList(links: [Link]) -> some View {
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

    // MARK: - AI Search

    func runAISearch() async {
        isSearching = true
        if #available(iOS 26, *) {
            await vm.aiSearch(query: vm.searchQuery)
        }
        isSearching = false
    }
}
