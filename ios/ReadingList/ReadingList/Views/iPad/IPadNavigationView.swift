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
}

// MARK: - Main iPad navigation (2-column: sidebar + full-width detail)

struct IPadNavigationView: View {
    @Environment(LibraryViewModel.self) private var vm
    @Environment(AuthViewModel.self) private var authVM
    @State private var selectedSidebar: SidebarItem? = .read
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
                .navigationTitle("Procrastinate")
        } detail: {
            mainContent
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Sidebar

    var sidebarContent: some View {
        List(selection: $selectedSidebar) {
            Section("Reading") {
                Label("Read", systemImage: "book").tag(SidebarItem.read)
                Label("Do", systemImage: "hammer").tag(SidebarItem.toDo)
                Label("Library", systemImage: "books.vertical").tag(SidebarItem.library)
            }
            Section("Discover") {
                Label("Sources", systemImage: "globe").tag(SidebarItem.sources)
                Label("Insights", systemImage: "chart.bar.xaxis.ascending.badge.clock").tag(SidebarItem.insights)
                Label("Notes Review", systemImage: "note.text").tag(SidebarItem.notes)
                Label("Knowledge Synthesis", systemImage: "brain").tag(SidebarItem.knowledge)
                Label("Search", systemImage: "magnifyingglass").tag(SidebarItem.search)
            }
            Section {
                Label("Profile", systemImage: "person.circle").tag(SidebarItem.profile)
            }
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
            Text(value).font(.headline).fontWeight(.bold).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Main content (full-width detail column)

    @ViewBuilder
    var mainContent: some View {
        switch selectedSidebar {
        case .read:
            IPadReadingPane(statusFilter: "to-read")
                .environment(vm).environment(authVM)
        case .toDo:
            IPadReadingPane(statusFilter: "to-try")
                .environment(vm).environment(authVM)
        case .library:
            IPadReadingPane(statusFilter: nil)
                .environment(vm).environment(authVM)
        case .sources:
            SourcesView().environment(vm)
        case .insights:
            LibraryInsightsView().environment(vm)
        case .notes:
            NotesReviewView().environment(vm)
        case .knowledge:
            KnowledgeSynthesisView().environment(vm)
        case .search:
            SearchView().environment(vm)
        case .profile:
            ProfileView().environment(vm).environment(authVM)
        case .none:
            ContentUnavailableView("Select a section", systemImage: "sidebar.left",
                                   description: Text("Choose from the sidebar"))
        }
    }
}

// MARK: - Reading pane: full-width card grid → collapses to list+reader on selection

struct IPadReadingPane: View {
    let statusFilter: String?
    @Environment(LibraryViewModel.self) private var vm
    @Environment(AuthViewModel.self) private var authVM
    @State private var selectedLink: Link? = nil
    @State private var isInfoMode: Bool = false
    @State private var isFullScreen: Bool = false
    @State private var showDetailInfo: Bool = false
    @State private var showFinished: Bool = false
    @AppStorage("libraryViewMode") private var viewMode: String = "cards"

    var isDoTab: Bool { statusFilter == "to-try" }

    var body: some View {
        GeometryReader { geo in
            let portrait = geo.size.height > geo.size.width

            Group {
                if let link = selectedLink, portrait || isFullScreen {
                    // Portrait or fullscreen: reader fills everything
                    readerView(link: link, geo: geo)
                } else if selectedLink == nil {
                    // Nothing selected: full-width view
                    if isDoTab || viewMode == "list" {
                        IPadArticleList(statusFilter: statusFilter, selectedLink: $selectedLink, isInfoMode: $isInfoMode)
                            .environment(vm).environment(authVM)
                    } else {
                        IPadCardGrid(statusFilter: statusFilter, selectedLink: $selectedLink)
                            .environment(vm)
                    }
                } else if let link = selectedLink {
                    // Landscape + article selected: narrow list on left, reader on right
                    HStack(spacing: 0) {
                        IPadArticleList(statusFilter: statusFilter, selectedLink: $selectedLink, isInfoMode: $isInfoMode)
                            .environment(vm).environment(authVM)
                            .frame(width: min(400, geo.size.width * 0.38))
                        Divider()
                        readerView(link: link, geo: geo)
                    }
                }
            }
            .animation(.spring(duration: 0.38, bounce: 0.05), value: selectedLink == nil)
            .sheet(isPresented: $showFinished) {
                if let link = selectedLink {
                    FinishedReadingSheet(link: link, vm: vm) {
                        showFinished = false
                        selectedLink = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    func readerView(link: Link, geo: GeometryProxy) -> some View {
        let portrait = geo.size.height > geo.size.width
        if isInfoMode {
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
                    if portrait || isFullScreen {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                if isFullScreen && !portrait {
                                    isFullScreen = false
                                } else {
                                    selectedLink = nil
                                }
                            } label: { Image(systemName: "chevron.left") }
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            Haptics.success()
                            showFinished = true
                        } label: {
                            Image(systemName: link.status == "done" ? "checkmark.circle.fill" : "checkmark.circle")
                                .foregroundStyle(link.status == "done" ? .green : .primary)
                        }
                        .help("Mark as done (⇧⌘D)")
                        .keyboardShortcut("d", modifiers: [.command, .shift])

                        Button { showDetailInfo = true } label: { Image(systemName: "info.circle") }
                            .help("Article info")

                        Button { UIPasteboard.general.string = link.url } label: { Image(systemName: "doc.on.doc") }
                            .help("Copy URL")

                        Button { UIApplication.shared.open(url) } label: { Image(systemName: "safari") }
                            .help("Open in Safari")

                        if !portrait {
                            Button {
                                isFullScreen.toggle()
                            } label: {
                                Image(systemName: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            }
                            .help(isFullScreen ? "Exit full screen" : "Full screen")
                            .keyboardShortcut("f", modifiers: [.command, .shift])
                        }
                    }
                }
                .sheet(isPresented: $showDetailInfo) {
                    ArticleDetailView(link: link).environment(vm)
                }
        } else {
            ContentUnavailableView("Invalid URL", systemImage: "link.badge.plus")
        }
    }
}

// MARK: - iPad Card Grid (full-width, shown when no article is selected)

struct IPadCardGrid: View {
    let statusFilter: String?
    @Binding var selectedLink: Link?

    @Environment(LibraryViewModel.self) private var vm
    @State private var isCurating = false
    @State private var curateSelection: Set<String> = []
    @State private var showCurateSheet = false
    @State private var infoLink: Link? = nil

    var displayedLinks: [Link] {
        var result = vm.allLinks
        if let sf = statusFilter { result = result.filter { $0.status == sf } }
        if let category = vm.selectedCategory { result = result.filter { $0.category == category } }
        if vm.sortByStars { result = result.sorted { ($0.stars ?? 0) > ($1.stars ?? 0) } }
        return result
    }

    var navTitle: String {
        switch statusFilter {
        case "to-read": return "Read"
        default: return "Library"
        }
    }

    @AppStorage("libraryViewMode") private var viewMode: String = "cards"

    // Adaptive: 3 cols on iPad landscape, 2 on portrait, more on large Mac windows
    let columns = [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(displayedLinks) { link in
                    ArticleCardView(link: link)
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .onTapGesture {
                            if isCurating {
                                if curateSelection.contains(link.id) { curateSelection.remove(link.id) }
                                else { curateSelection.insert(link.id) }
                            } else {
                                Haptics.tap()
                                selectedLink = link
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if isCurating {
                                Image(systemName: curateSelection.contains(link.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(curateSelection.contains(link.id) ? Color.accentColor : .white)
                                    .shadow(color: .black.opacity(0.4), radius: 3)
                                    .padding(10)
                            }
                        }
                        .contextMenu {
                            Button { infoLink = link } label: { Label("Info", systemImage: "info.circle") }
                            Divider()
                            Button { UIPasteboard.general.string = link.url } label: { Label("Copy URL", systemImage: "doc.on.doc") }
                            Button { guard let url = URL(string: link.url) else { return }
                                UIApplication.shared.open(url) } label: { Label("Open in Safari", systemImage: "safari") }
                            Divider()
                            Button { Task { await vm.updateStatus(link: link, status: "to-read") } } label: { Label("To Read", systemImage: "book") }
                            Button { Task { await vm.updateStatus(link: link, status: "to-try") } } label: { Label("To Do", systemImage: "hammer") }
                            Button { Task { await vm.updateStatus(link: link, status: "done") } } label: { Label("Done", systemImage: "checkmark.circle") }
                            Divider()
                            Button(role: .destructive) { Task { await vm.delete(link: link) } } label: { Label("Delete", systemImage: "trash") }
                        }
                }
            }
            .padding(20)
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await vm.refresh() }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let progress = vm.enrichAllProgress {
                HStack(spacing: 12) {
                    ProgressView().scaleEffect(0.8)
                    Text("Enriching \(progress.current) of \(progress.total)…").font(.subheadline)
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.regularMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if isCurating {
                HStack {
                    Button("Cancel") { withAnimation { isCurating = false; curateSelection.removeAll() } }
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(curateSelection.count) selected").font(.subheadline).fontWeight(.medium)
                    Spacer()
                    Button("Create Link") { showCurateSheet = true }
                        .fontWeight(.semibold).disabled(curateSelection.isEmpty)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.regularMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: vm.enrichAllProgress != nil || isCurating)
        .sheet(isPresented: $showCurateSheet) {
            CurateSheetView(selectedLinks: displayedLinks.filter { curateSelection.contains($0.id) }) {
                isCurating = false; curateSelection.removeAll()
            }
            .environment(vm)
        }
        .sheet(item: $infoLink) { link in
            ArticleDetailView(link: link).environment(vm)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewMode = "list"
                } label: {
                    Image(systemName: "list.bullet")
                }
                .help("Switch to list view")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if !vm.categories.isEmpty {
                        Menu {
                            Button { vm.selectedCategory = nil } label: {
                                Label("All", systemImage: vm.selectedCategory == nil ? "checkmark" : "tray.full")
                            }
                            ForEach(vm.categories) { cat in
                                Button { vm.selectedCategory = cat.name } label: {
                                    Label { Text(cat.name) } icon: {
                                        if vm.selectedCategory == cat.name { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        } label: { Label(vm.selectedCategory ?? "Category", systemImage: "folder") }
                    }
                    Section("Sort") {
                        Button { vm.sortByStars = false } label: { Label("Newest", systemImage: vm.sortByStars ? "clock" : "checkmark") }
                        Button { vm.sortByStars = true } label: { Label("Top Rated", systemImage: vm.sortByStars ? "checkmark" : "star.fill") }
                    }
                    Section {
                        Button { withAnimation { isCurating = true; curateSelection.removeAll() } } label: {
                            Label("Curate Collection", systemImage: "rectangle.stack.badge.plus")
                        }
                        if #available(iOS 26, *) {
                            Button { Task { await vm.enrichAll() } } label: {
                                let count = vm.unenrichedLinks.count
                                Label(count > 0 ? "Enrich All (\(count))" : "All Enriched", systemImage: "sparkles")
                            }
                            .disabled(vm.unenrichedLinks.isEmpty || vm.isEnrichingAll)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }
}

// MARK: - iPad Article List

struct IPadArticleList: View {
    let statusFilter: String?
    @Binding var selectedLink: Link?
    @Binding var isInfoMode: Bool

    @Environment(LibraryViewModel.self) private var vm
    @Environment(AuthViewModel.self) private var authVM
    @State private var infoLink: Link? = nil
    @State private var isCurating = false
    @State private var curateSelection: Set<String> = []
    @State private var showCurateSheet = false
    @AppStorage("libraryViewMode") private var viewMode: String = "cards"

    var displayedLinks: [Link] {
        var result = vm.allLinks
        if let sf = statusFilter { result = result.filter { $0.status == sf } }
        if let category = vm.selectedCategory { result = result.filter { $0.category == category } }
        if vm.sortByStars { result = result.sorted { ($0.stars ?? 0) > ($1.stars ?? 0) } }
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
                    }, onTap: { selectedLink = link })
                    .tag(link)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { Task { await vm.delete(link: link) } } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } else if isCurating {
                    HStack {
                        Image(systemName: curateSelection.contains(link.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(curateSelection.contains(link.id) ? Color.accentColor : .secondary)
                            .font(.title3)
                        iPadRow(link: link)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if curateSelection.contains(link.id) { curateSelection.remove(link.id) }
                        else { curateSelection.insert(link.id) }
                    }
                    .tag(link).listRowSeparator(.visible)
                } else {
                    iPadRow(link: link)
                        .tag(link).listRowSeparator(.visible)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                Haptics.success()
                                Task { await vm.updateStatus(link: link, status: link.status == "done" ? nil : "done") }
                            } label: {
                                Label(link.status == "done" ? "Undo" : "Done",
                                      systemImage: link.status == "done" ? "arrow.uturn.backward" : "checkmark")
                            }.tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { Task { await vm.delete(link: link) } } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { Haptics.success(); Task { await vm.updateStatus(link: link, status: "to-try") } } label: {
                                Label("Do", systemImage: "hammer")
                            }.tint(.blue)
                            Button { infoLink = link } label: {
                                Label("Info", systemImage: "info.circle")
                            }.tint(.indigo)
                        }
                        .contextMenu {
                            Button { infoLink = link } label: { Label("Info", systemImage: "info.circle") }
                            Divider()
                            Button { UIPasteboard.general.string = link.url } label: { Label("Copy URL", systemImage: "doc.on.doc") }
                            Button { guard let url = URL(string: link.url) else { return }; UIApplication.shared.open(url) } label: { Label("Open in Safari", systemImage: "safari") }
                            Divider()
                            Button { Task { await vm.updateStatus(link: link, status: "to-read") } } label: { Label("To Read", systemImage: "book") }
                            Button { Task { await vm.updateStatus(link: link, status: "to-try") } } label: { Label("To Do", systemImage: "hammer") }
                            Button { Task { await vm.updateStatus(link: link, status: "done") } } label: { Label("Done", systemImage: "checkmark.circle") }
                            Divider()
                            Button(role: .destructive) { Task { await vm.delete(link: link) } } label: { Label("Delete", systemImage: "trash") }
                        }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(navTitle)
        .refreshable { await vm.refresh() }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let progress = vm.enrichAllProgress {
                HStack(spacing: 12) {
                    ProgressView().scaleEffect(0.8)
                    Text("Enriching \(progress.current) of \(progress.total)…").font(.subheadline)
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.regularMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if isCurating {
                HStack {
                    Button("Cancel") { withAnimation { isCurating = false; curateSelection.removeAll() } }
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(curateSelection.count) selected").font(.subheadline).fontWeight(.medium)
                    Spacer()
                    Button("Create Link") { showCurateSheet = true }
                        .fontWeight(.semibold).disabled(curateSelection.isEmpty)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.regularMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: vm.enrichAllProgress != nil || isCurating)
        .sheet(isPresented: $showCurateSheet) {
            CurateSheetView(selectedLinks: displayedLinks.filter { curateSelection.contains($0.id) }) {
                isCurating = false; curateSelection.removeAll()
            }
            .environment(vm)
        }
        .sheet(item: $infoLink) { link in
            ArticleDetailView(link: link).environment(vm)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewMode = "cards"
                    selectedLink = nil
                } label: {
                    Image(systemName: "square.grid.2x2")
                }
                .help("Switch to card view")
            }
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
                                        if vm.selectedCategory == cat.name { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        } label: { Label(vm.selectedCategory ?? "Category", systemImage: "folder") }
                    }
                    Section("Sort") {
                        Button { vm.sortByStars = false } label: { Label("Newest", systemImage: vm.sortByStars ? "clock" : "checkmark") }
                        Button { vm.sortByStars = true } label: { Label("Top Rated", systemImage: vm.sortByStars ? "checkmark" : "star.fill") }
                    }
                    Section {
                        Button { isInfoMode.toggle() } label: {
                            Label(isInfoMode ? "Exit Info Mode" : "Info Mode",
                                  systemImage: isInfoMode ? "info.circle.fill" : "info.circle")
                        }
                        Button { withAnimation { isCurating = true; curateSelection.removeAll() } } label: {
                            Label("Curate Collection", systemImage: "rectangle.stack.badge.plus")
                        }
                        if #available(iOS 26, *) {
                            Button { Task { await vm.enrichAll() } } label: {
                                let count = vm.unenrichedLinks.count
                                Label(count > 0 ? "Enrich All (\(count))" : "All Enriched", systemImage: "sparkles")
                            }
                            .disabled(vm.unenrichedLinks.isEmpty || vm.isEnrichingAll)
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
            if let rawURL = link.image, let imageURL = URL(string: rawURL) {
                CachedAsyncImage(url: imageURL) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: { fallbackThumb(for: link) }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                fallbackThumb(for: link)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(link.title ?? link.url).font(.subheadline).fontWeight(.semibold).lineLimit(2)
                HStack(spacing: 6) {
                    if let domain = link.domain { Text(domain).font(.caption).foregroundStyle(.secondary) }
                    if let status = link.status { StatusPill(status: status) }
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

// Make Link selectable in List
extension Link: Hashable {
    static func == (lhs: Link, rhs: Link) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status && lhs.stars == rhs.stars &&
        lhs.note == rhs.note && lhs.summary == rhs.summary && lhs.tags == rhs.tags &&
        lhs.category == rhs.category && lhs.title == rhs.title && lhs.read == rhs.read
    }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
