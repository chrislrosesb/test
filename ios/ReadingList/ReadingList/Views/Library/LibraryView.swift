import SwiftUI

struct LibraryView: View {
    @Environment(LibraryViewModel.self) private var vm
    @Environment(AuthViewModel.self) private var authVM

    /// nil = show all (Library tab), "to-read" = Read tab, "to-try" = Do tab
    var statusFilter: String?

    @State private var selectedLink: Link? = nil
    @State private var selectedIndex: Int = 0
    @State private var appeared = true
    @State private var showProfile = false
    @State private var showSources = false
    @State private var showDigest = false
    @State private var showInsights = false
    @State private var showNotesReview = false
    @State private var showKnowledgeSynthesis = false
    @State private var isCurating = false
    @State private var curateSelection: Set<String> = []
    @State private var showCurateSheet = false
    @State private var infoLink: Link? = nil
    @State private var showTagCloud = false
    @AppStorage("libraryViewMode") private var viewMode: String = "cards"

    var navTitle: String {
        switch statusFilter {
        case "to-read": return "Read"
        case "to-try": return "Do"
        default: return "Library"
        }
    }

    /// Articles for this tab, with additional filters applied
    var displayedLinks: [Link] {
        var result = vm.allLinks

        // Tab-level status filter
        if let sf = statusFilter {
            result = result.filter { $0.status == sf }
        }

        // Additional filters from menu
        if let category = vm.selectedCategory {
            result = result.filter { $0.category == category }
        }
        if vm.sortByStars {
            result = result.sorted { ($0.stars ?? 0) > ($1.stars ?? 0) }
        }
        if let tag = vm.selectedTag {
            result = result.filter { link in
                guard let tags = link.tags else { return false }
                return tags.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                    .contains(tag.lowercased())
            }
        }
        if !vm.searchQuery.isEmpty {
            let tokens = vm.searchQuery.lowercased().split(separator: " ").map(String.init)
            result = result.filter { link in
                let haystack = [link.title, link.description, link.note, link.summary, link.domain, link.category, link.tags]
                    .compactMap { $0 }.joined(separator: " ").lowercased()
                return tokens.allSatisfy { haystack.contains($0) }
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.allLinks.isEmpty {
                    loadingView
                } else if displayedLinks.isEmpty {
                    emptyView
                } else {
                    articleList
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .background(Color(.systemBackground))
        }
        .fullScreenCover(item: $selectedLink) { link in
            ArticleReaderContainer(
                links: displayedLinks,
                initialIndex: selectedIndex,
                vm: vm
            )
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
                .environment(vm)
                .environment(authVM)
        }
        .sheet(isPresented: $showSources) {
            SourcesView()
                .environment(vm)
        }
        .sheet(isPresented: $showDigest) {
            DigestView()
                .environment(vm)
        }
        .sheet(isPresented: $showInsights) {
            LibraryInsightsView()
                .environment(vm)
        }
        .sheet(isPresented: $showNotesReview) {
            NotesReviewView()
                .environment(vm)
        }
        .sheet(isPresented: $showKnowledgeSynthesis) {
            KnowledgeSynthesisView()
                .environment(vm)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let progress = vm.enrichAllProgress {
                HStack(spacing: 12) {
                    ProgressView().scaleEffect(0.8)
                    Text("Enriching \(progress.current) of \(progress.total)…")
                        .font(.caption).fontWeight(.medium)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.regularMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let error = vm.errorMessage {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(error).font(.caption).lineLimit(2)
                    Spacer()
                    Button { vm.errorMessage = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.regularMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: vm.errorMessage)
        .overlay(alignment: .bottom) {
            if isCurating {
                HStack {
                    Button("Cancel") {
                        withAnimation { isCurating = false; curateSelection.removeAll() }
                    }
                    .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(curateSelection.count) selected")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Button("Create Link") {
                        showCurateSheet = true
                    }
                    .fontWeight(.semibold)
                    .disabled(curateSelection.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.regularMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: isCurating)
        .sheet(isPresented: $showCurateSheet) {
            CurateSheetView(
                selectedLinks: displayedLinks.filter { curateSelection.contains($0.id) }
            ) {
                isCurating = false
                curateSelection.removeAll()
            }
        }
        .sheet(item: $infoLink) { link in
            ArticleDetailView(link: link)
                .environment(vm)
        }
        .sheet(isPresented: $showTagCloud) {
            TagCloudView(tagCounts: vm.tagCounts) { tag in
                vm.selectedTag = tag
            }
        }
    }

    // MARK: - Article List

    var isDoTab: Bool { statusFilter == "to-try" }

    var articleList: some View {
        List {
            if isDoTab {
                // Task-style list for Do tab
                ForEach(displayedLinks) { link in
                    TaskRowView(link: link, onToggleDone: {
                        Task { await vm.updateStatus(link: link, status: "done") }
                    }, onTap: {
                        if let idx = displayedLinks.firstIndex(where: { $0.id == link.id }) {
                            selectedIndex = idx
                            selectedLink = link
                        }
                    })
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await vm.delete(link: link) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } else {
                // Standard card/row list
                ForEach(Array(displayedLinks.enumerated()), id: \.element.id) { index, link in
                    Group {
                        if viewMode == "cards" {
                            ArticleCardView(link: link)
                        } else {
                            ArticleRowView(link: link)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if isCurating {
                            Image(systemName: curateSelection.contains(link.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(curateSelection.contains(link.id) ? Color.accentColor : .secondary)
                                .padding(12)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Haptics.tap()
                        if isCurating {
                            if curateSelection.contains(link.id) {
                                curateSelection.remove(link.id)
                            } else {
                                _ = curateSelection.insert(link.id)
                            }
                        } else {
                            selectedIndex = index
                            selectedLink = link
                        }
                    }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        Haptics.success()
                        Task { await vm.updateStatus(link: link, status: link.status == "done" ? nil : "done") }
                    } label: {
                        Label(link.status == "done" ? "Undo" : "Done", systemImage: link.status == "done" ? "arrow.uturn.backward" : "checkmark")
                    }
                    .tint(.green)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task { await vm.delete(link: link) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        Haptics.success()
                        Task { await vm.updateStatus(link: link, status: "to-try") }
                    } label: {
                        Label("Do", systemImage: "hammer")
                    }
                    .tint(.blue)
                    Button {
                        infoLink = link
                    } label: {
                        Label("Info", systemImage: "info.circle")
                    }
                    .tint(.indigo)
                }
                .contextMenu { if !isCurating { contextMenu(for: link) } }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
            } // end else (standard list)
        }
        .listStyle(.plain)
        .refreshable { await vm.refresh() }
    }

    // MARK: - Context Menu

    @ViewBuilder
    func contextMenu(for link: Link) -> some View {
        Button {
            infoLink = link
        } label: {
            Label("Info", systemImage: "info.circle")
        }
        Divider()
        Button {
            UIPasteboard.general.string = link.url
        } label: {
            Label("Copy URL", systemImage: "doc.on.doc")
        }
        Button {
            guard let url = URL(string: link.url) else { return }
            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                root.present(av, animated: true)
            }
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        Button {
            guard let url = URL(string: link.url) else { return }
            UIApplication.shared.open(url)
        } label: {
            Label("Open in Safari", systemImage: "safari")
        }
        Divider()
        statusMenu(for: link)
        Divider()
        Button(role: .destructive) {
            Task { await vm.delete(link: link) }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @ViewBuilder
    func statusMenu(for link: Link) -> some View {
        ForEach(["to-read", "to-try", "done"], id: \.self) { status in
            Button {
                Task { await vm.updateStatus(link: link, status: status) }
            } label: {
                Label(StatusPill(status: status).label, systemImage: statusIcon(status))
            }
        }
        if link.status != nil {
            Divider()
            Button {
                Task { await vm.updateStatus(link: link, status: nil) }
            } label: {
                Label("Clear Status", systemImage: "xmark.circle")
            }
        }
    }

    func statusIcon(_ status: String) -> String {
        switch status {
        case "to-read": return "book"
        case "to-try": return "hammer"
        case "done": return "checkmark.circle"
        default: return "circle"
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                // Today's Digest
                Button { showDigest = true } label: {
                    Label("Today's Reading", systemImage: "sun.max")
                }

                // Library Insights
                Button { showInsights = true } label: {
                    Label("Library Insights", systemImage: "chart.bar.xaxis.ascending.badge.clock")
                }

                // Notes Review
                Button { showNotesReview = true } label: {
                    Label("Notes Review", systemImage: "note.text")
                }

                // Sources
                Button { showSources = true } label: {
                    Label("Sources", systemImage: "globe")
                }

                // Categories (sub-menu)
                if !vm.categories.isEmpty {
                    Menu {
                        Button {
                            vm.selectedCategory = nil
                        } label: {
                            Label("All", systemImage: vm.selectedCategory == nil ? "checkmark" : "tray.full")
                        }
                        ForEach(vm.categories) { cat in
                            Button {
                                vm.selectedCategory = cat.name
                            } label: {
                                Label {
                                    Text(cat.name)
                                } icon: {
                                    if vm.selectedCategory == cat.name {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label(vm.selectedCategory ?? "Category", systemImage: "folder")
                    }
                }

                // Sort
                Section("Sort") {
                    Button {
                        vm.sortByStars = false
                    } label: {
                        Label("Newest First", systemImage: vm.sortByStars ? "clock" : "checkmark")
                    }
                    Button {
                        vm.sortByStars = true
                    } label: {
                        Label("Highest Rated", systemImage: vm.sortByStars ? "checkmark" : "star.fill")
                    }
                }

                // Curate
                Section("Share") {
                    Button {
                        withAnimation { isCurating = true; curateSelection.removeAll() }
                    } label: {
                        Label("Curate Collection", systemImage: "rectangle.stack.badge.plus")
                    }
                }

                // AI
                Section("AI") {
                    Button { showKnowledgeSynthesis = true } label: {
                        Label("Knowledge Synthesis", systemImage: "brain")
                    }

                    Button {
                        if #available(iOS 26, *) {
                            Task { await vm.enrichAll() }
                        }
                    } label: {
                        let count = vm.unenrichedLinks.count
                        Label(count > 0 ? "Enrich All (\(count))" : "All Enriched", systemImage: "sparkles")
                    }
                    .disabled(vm.unenrichedLinks.isEmpty || vm.isEnrichingAll)
                }

                // Active tag
                if let tag = vm.selectedTag {
                    Section("Tag Filter") {
                        Button(role: .destructive) {
                            vm.selectedTag = nil
                        } label: {
                            Label("Clear: \(tag)", systemImage: "tag.slash")
                        }
                    }
                }

                // Clear all
                if vm.hasActiveFilters {
                    Section {
                        Button(role: .destructive) {
                            vm.selectedCategory = nil
                            vm.selectedTag = nil
                            vm.sortByStars = false
                        } label: {
                            Label("Clear All Filters", systemImage: "xmark.circle")
                        }
                    }
                }
            } label: {
                Image(systemName: vm.hasActiveFilters
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                    .foregroundStyle(vm.hasActiveFilters ? Color.accentColor : Color.primary)
                    .symbolEffect(.bounce, value: vm.hasActiveFilters)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showTagCloud = true
            } label: {
                Image(systemName: vm.selectedTag != nil ? "tag.fill" : "tag")
                    .foregroundStyle(vm.selectedTag != nil ? Color.indigo : Color.primary)
                    .symbolEffect(.bounce, value: vm.selectedTag)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    viewMode = viewMode == "cards" ? "list" : "cards"
                }
            } label: {
                Image(systemName: viewMode == "cards" ? "list.bullet" : "square.grid.2x2")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showProfile = true } label: {
                Image(systemName: "person.circle")
            }
        }
    }

    // MARK: - Empty / Loading

    var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.3)
            Text("Loading your library…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    var emptyView: some View {
        if !vm.searchQuery.isEmpty {
            ContentUnavailableView.search(text: vm.searchQuery)
        } else if vm.hasActiveFilters || statusFilter != nil {
            ContentUnavailableView(
                "No Articles",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("No articles matching these filters.")
            )
        } else {
            ContentUnavailableView(
                "Your Library is Empty",
                systemImage: "books.vertical",
                description: Text("Save articles from Safari using your Shortcut.")
            )
        }
    }
}
