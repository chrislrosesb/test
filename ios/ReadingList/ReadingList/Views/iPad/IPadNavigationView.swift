import SwiftUI

enum SidebarItem: String, Hashable, CaseIterable {
    case library = "Library"
    case read = "Read"
    case toDo = "Do"
    case sources = "Sources"
    case insights = "Insights"
    case notes = "Notes"
    case knowledge = "Knowledge"
    case search = "Search"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .library: return "books.vertical"
        case .read: return "book"
        case .toDo: return "hammer"
        case .sources: return "globe"
        case .insights: return "chart.bar.xaxis.ascending.badge.clock"
        case .notes: return "note.text"
        case .knowledge: return "brain"
        case .search: return "magnifyingglass"
        case .profile: return "person.circle"
        }
    }

    var statusFilter: String? {
        switch self {
        case .read: return "to-read"
        case .toDo: return "to-try"
        default: return nil
        }
    }
}

struct IPadNavigationView: View {
    @Environment(LibraryViewModel.self) private var vm
    @Environment(AuthViewModel.self) private var authVM

    @State private var selectedSidebar: SidebarItem? = .read
    @State private var selectedLink: Link? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var isPortrait: Bool = UIScreen.main.bounds.height > UIScreen.main.bounds.width
    @State private var isFullScreen = false
    @State private var isInfoMode = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            sidebarContent
                .navigationTitle("Procrastinate")
        } content: {
            // Article list
            contentColumn
        } detail: {
            // Reader
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        isPortrait = geo.size.height > geo.size.width
                    }
                    .onChange(of: geo.size) { _, size in
                        let nowPortrait = size.height > size.width
                        if nowPortrait != isPortrait {
                            isPortrait = nowPortrait
                            // Rotating to landscape — restore columns (unless fullscreen)
                            if !nowPortrait && !isFullScreen {
                                columnVisibility = .automatic
                            }
                            // Rotating to portrait with article open — go full-screen
                            if nowPortrait && selectedLink != nil {
                                columnVisibility = .detailOnly
                            }
                        }
                    }
            }
        )
        .onChange(of: selectedLink) { _, newLink in
            if isPortrait {
                columnVisibility = newLink != nil ? .detailOnly : .automatic
            }
            if newLink == nil && isFullScreen {
                isFullScreen = false
                columnVisibility = .automatic
            }
        }
    }

    // MARK: - Sidebar

    var sidebarContent: some View {
        List(selection: $selectedSidebar) {
            Section("Reading") {
                Label("Read", systemImage: "book")
                    .tag(SidebarItem.read)
                Label("Do", systemImage: "hammer")
                    .tag(SidebarItem.toDo)
                Label("Library", systemImage: "books.vertical")
                    .tag(SidebarItem.library)
            }

            Section("Discover") {
                Label("Sources", systemImage: "globe")
                    .tag(SidebarItem.sources)
                Label("Insights", systemImage: "chart.bar.xaxis.ascending.badge.clock")
                    .tag(SidebarItem.insights)
                Label("Notes Review", systemImage: "note.text")
                    .tag(SidebarItem.notes)
                Label("Knowledge Synthesis", systemImage: "brain")
                    .tag(SidebarItem.knowledge)
                Label("Search", systemImage: "magnifyingglass")
                    .tag(SidebarItem.search)
            }

            Section {
                Label("Profile", systemImage: "person.circle")
                    .tag(SidebarItem.profile)
            }

            // Stats at bottom of sidebar
            Section {
                HStack(spacing: 16) {
                    sidebarStat("\(vm.allLinks.filter { $0.status == "to-read" }.count)", label: "Read", color: .blue)
                    sidebarStat("\(vm.allLinks.filter { $0.status == "to-try" }.count)", label: "Do", color: .orange)
                    sidebarStat("\(vm.allLinks.filter { $0.status == "done" }.count)", label: "Done", color: .green)
                }
                .listRowBackground(Color.clear)
            }
        }
    }

    func sidebarStat(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Content Column (article list)

    @ViewBuilder
    var contentColumn: some View {
        switch selectedSidebar {
        case .library:
            IPadArticleList(statusFilter: nil, selectedLink: $selectedLink, isInfoMode: $isInfoMode)
                .environment(vm)
                .environment(authVM)
        case .read:
            IPadArticleList(statusFilter: "to-read", selectedLink: $selectedLink, isInfoMode: $isInfoMode)
                .environment(vm)
                .environment(authVM)
        case .toDo:
            IPadArticleList(statusFilter: "to-try", selectedLink: $selectedLink, isInfoMode: $isInfoMode)
                .environment(vm)
                .environment(authVM)
        case .sources:
            SourcesView()
                .environment(vm)
        case .insights:
            LibraryInsightsView()
                .environment(vm)
        case .notes:
            NotesReviewView()
                .environment(vm)
        case .knowledge:
            KnowledgeSynthesisView()
                .environment(vm)
        case .search:
            SearchView()
                .environment(vm)
        case .profile:
            ProfileView()
                .environment(vm)
                .environment(authVM)
        case .none:
            ContentUnavailableView("Select a section", systemImage: "sidebar.left", description: Text("Choose from the sidebar"))
        }
    }

    // MARK: - Detail Column (reader)

    @State private var showDetailInfo = false

    @ViewBuilder
    var detailColumn: some View {
        if let link = selectedLink {
            if isInfoMode {
                // Info mode: show editable metadata inline
                ArticleDetailView(link: link)
                    .id(link.id + "info")
                    .environment(vm)
            } else if let url = URL(string: link.url) {
                WebView(url: url)
                    .id(link.id)
                    .ignoresSafeArea(edges: .bottom)
                    .navigationTitle(link.title ?? link.domain ?? "Article")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        if isPortrait || isFullScreen {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    if isFullScreen && !isPortrait {
                                        isFullScreen = false
                                        columnVisibility = .automatic
                                    } else {
                                        selectedLink = nil
                                        columnVisibility = .automatic
                                    }
                                } label: {
                                    Image(systemName: "chevron.left")
                                }
                                .help(isFullScreen && !isPortrait ? "Exit full screen" : "Back to list")
                            }
                        }
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Button {
                                Haptics.success()
                                Task { await vm.updateStatus(link: link, status: "done") }
                            } label: {
                                Image(systemName: link.status == "done" ? "checkmark.circle.fill" : "checkmark.circle")
                                    .foregroundStyle(link.status == "done" ? .green : .primary)
                            }
                            .help("Mark as done (⇧⌘D)")
                            .keyboardShortcut("d", modifiers: [.command, .shift])

                            Button { showDetailInfo = true } label: {
                                Image(systemName: "info.circle")
                            }
                            .help("Article info")

                            Button {
                                UIPasteboard.general.string = link.url
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .help("Copy URL")

                            Button {
                                UIApplication.shared.open(url)
                            } label: {
                                Image(systemName: "safari")
                            }
                            .help("Open in Safari")

                            // Fullscreen toggle (landscape only)
                            if !isPortrait {
                                Button {
                                    isFullScreen.toggle()
                                    columnVisibility = isFullScreen ? .detailOnly : .automatic
                                } label: {
                                    Image(systemName: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                }
                                .help(isFullScreen ? "Exit full screen" : "Full screen")
                                .keyboardShortcut("f", modifiers: [.command, .shift])
                            }
                        }
                    }
                    .sheet(isPresented: $showDetailInfo) {
                        ArticleDetailView(link: link)
                            .environment(vm)
                    }
            } else {
                ContentUnavailableView("Invalid URL", systemImage: "link.badge.plus")
            }
        } else {
            ContentUnavailableView("Select an article", systemImage: "doc.text", description: Text("Choose an article to start reading"))
        }
    }
}

// MARK: - iPad Article List (middle column)

struct IPadArticleList: View {
    let statusFilter: String?
    @Binding var selectedLink: Link?
    @Binding var isInfoMode: Bool

    @Environment(LibraryViewModel.self) private var vm
    @Environment(AuthViewModel.self) private var authVM
    @State private var infoLink: Link? = nil

    var displayedLinks: [Link] {
        var result = vm.allLinks
        if let sf = statusFilter {
            result = result.filter { $0.status == sf }
        }
        if let category = vm.selectedCategory {
            result = result.filter { $0.category == category }
        }
        if vm.sortByStars {
            result = result.sorted { ($0.stars ?? 0) > ($1.stars ?? 0) }
        }
        return result
    }

    var isDoTab: Bool { statusFilter == "to-try" }

    var navTitle: String {
        switch statusFilter {
        case "to-read": return "Read"
        case "to-try": return "Do"
        default: return "Library"
        }
    }

    var body: some View {
        List(selection: $selectedLink) {
            ForEach(displayedLinks) { link in
                if isDoTab {
                    TaskRowView(link: link, onToggleDone: {
                        Task { await vm.updateStatus(link: link, status: "done") }
                    }, onTap: {
                        selectedLink = link
                    })
                    .tag(link)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await vm.delete(link: link) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } else {
                iPadRow(link: link)
                    .tag(link)
                    .listRowSeparator(.visible)
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
                    .contextMenu {
                        Button { infoLink = link } label: {
                            Label("Info", systemImage: "info.circle")
                        }
                        Divider()
                        Button { UIPasteboard.general.string = link.url } label: {
                            Label("Copy URL", systemImage: "doc.on.doc")
                        }
                        Button {
                            guard let url = URL(string: link.url) else { return }
                            UIApplication.shared.open(url)
                        } label: {
                            Label("Open in Safari", systemImage: "safari")
                        }
                        Divider()
                        Button { Task { await vm.updateStatus(link: link, status: "to-read") } } label: {
                            Label("To Read", systemImage: "book")
                        }
                        Button { Task { await vm.updateStatus(link: link, status: "to-try") } } label: {
                            Label("To Do", systemImage: "hammer")
                        }
                        Button { Task { await vm.updateStatus(link: link, status: "done") } } label: {
                            Label("Done", systemImage: "checkmark.circle")
                        }
                        Divider()
                        Button(role: .destructive) { Task { await vm.delete(link: link) } } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } // end else
            }
        }
        .listStyle(.plain)
        .navigationTitle(navTitle)
        .refreshable { await vm.refresh() }
        .sheet(item: $infoLink) { link in
            ArticleDetailView(link: link)
                .environment(vm)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if !vm.categories.isEmpty {
                        Menu {
                            Button { vm.selectedCategory = nil } label: {
                                Label("All", systemImage: vm.selectedCategory == nil ? "checkmark" : "tray.full")
                            }
                            ForEach(vm.categories) { cat in
                                Button { vm.selectedCategory = cat.name } label: {
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
                    Section("Sort") {
                        Button { vm.sortByStars = false } label: {
                            Label("Newest", systemImage: vm.sortByStars ? "clock" : "checkmark")
                        }
                        Button { vm.sortByStars = true } label: {
                            Label("Top Rated", systemImage: vm.sortByStars ? "checkmark" : "star.fill")
                        }
                    }
                    Section {
                        Button {
                            isInfoMode.toggle()
                        } label: {
                            Label(isInfoMode ? "Exit Info Mode" : "Info Mode", systemImage: isInfoMode ? "info.circle.fill" : "info.circle")
                        }
                    }
                } label: {
                    Image(systemName: isInfoMode ? "info.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .help(isInfoMode ? "Info Mode active" : "Filter & Sort")
            }
        }
    }

    func iPadRow(link: Link) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let rawURL = link.image, let imageURL = URL(string: rawURL) {
                CachedAsyncImage(url: imageURL) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    fallbackThumb(for: link)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                fallbackThumb(for: link)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(link.title ?? link.url)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let domain = link.domain {
                        Text(domain)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let status = link.status {
                        StatusPill(status: status)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    func fallbackThumb(for link: Link) -> some View {
        ZStack {
            LinearGradient(colors: domainGradient(for: link.domain), startPoint: .topLeading, endPoint: .bottomTrailing)
            if let first = link.domain?.first {
                Text(String(first).uppercased())
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

// Make Link selectable in List — must compare ALL fields so SwiftUI
// detects changes (not just id, or status/star updates won't re-render)
extension Link: Hashable {
    static func == (lhs: Link, rhs: Link) -> Bool {
        lhs.id == rhs.id &&
        lhs.status == rhs.status &&
        lhs.stars == rhs.stars &&
        lhs.note == rhs.note &&
        lhs.summary == rhs.summary &&
        lhs.tags == rhs.tags &&
        lhs.category == rhs.category &&
        lhs.title == rhs.title &&
        lhs.read == rhs.read
    }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
