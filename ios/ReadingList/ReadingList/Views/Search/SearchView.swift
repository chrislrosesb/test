import SwiftUI

struct SearchView: View {
    @Environment(LibraryViewModel.self) private var vm
    @State private var selectedLink: Link? = nil

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            Group {
                if vm.searchQuery.isEmpty {
                    searchPlaceholder
                } else if vm.filteredLinks.isEmpty {
                    ContentUnavailableView.search(text: vm.searchQuery)
                } else {
                    searchResults
                }
            }
            .navigationTitle("Search")
            .searchable(text: $vm.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search articles…")
        }
        .sheet(item: $selectedLink) { link in
            ArticleDetailView(link: link)
                .environment(vm)
        }
    }

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

    var searchResults: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(vm.filteredLinks) { link in
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
}
