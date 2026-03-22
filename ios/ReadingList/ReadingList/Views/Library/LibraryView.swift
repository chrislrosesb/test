import SwiftUI

struct LibraryView: View {
    @Environment(LibraryViewModel.self) private var vm
    @Environment(AuthViewModel.self) private var authVM

    @State private var selectedLink: Link? = nil
    @State private var selectedIndex: Int = 0
    @State private var appeared = false
    @AppStorage("libraryViewMode") private var viewMode: String = "cards"

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.allLinks.isEmpty {
                    loadingView
                } else if vm.filteredLinks.isEmpty {
                    emptyView
                } else {
                    articleList
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .background(Color(.systemBackground))
        }
        .fullScreenCover(item: $selectedLink) { link in
            ArticleReaderContainer(
                links: vm.filteredLinks,
                initialIndex: selectedIndex,
                vm: vm
            )
        }
        // Filter sheet removed — now uses inline Menu popover
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let error = vm.errorMessage {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .lineLimit(2)
                    Spacer()
                    Button { vm.errorMessage = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: vm.errorMessage)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.3).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Article List

    var articleList: some View {
        ScrollView {
            LazyVStack(spacing: viewMode == "cards" ? 16 : 0) {
                ForEach(Array(vm.filteredLinks.enumerated()), id: \.element.id) { index, link in
                    Group {
                        if viewMode == "cards" {
                            ArticleCardView(link: link)
                                .padding(.horizontal, 16)
                        } else {
                            ArticleRowView(link: link)
                            if index < vm.filteredLinks.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(
                        .spring(duration: 0.4, bounce: 0.3)
                        .delay(Double(min(index, 8)) * 0.04),
                        value: appeared
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedIndex = index
                        selectedLink = link
                    }
                    .contextMenu { contextMenu(for: link) }
                }
            }
            .padding(.vertical, 12)
            .padding(.bottom, 100)
        }
        .refreshable { await vm.refresh() }
    }

    // MARK: - Swipe Actions

    @ViewBuilder
    func trailingSwipeActions(for link: Link) -> some View {
        Button(role: .destructive) {
            Task { await vm.delete(link: link) }
        } label: {
            Label("Delete", systemImage: "trash")
        }
        Menu {
            statusMenu(for: link)
        } label: {
            Label("Status", systemImage: "tag")
        }
        .tint(.blue)
    }

    @ViewBuilder
    func leadingSwipeAction(for link: Link) -> some View {
        let isDone = link.status == "done"
        Button {
            Task { await vm.updateStatus(link: link, status: isDone ? nil : "done") }
        } label: {
            Label(isDone ? "Unread" : "Done", systemImage: isDone ? "book" : "checkmark")
        }
        .tint(isDone ? .gray : .green)
    }

    @ViewBuilder
    func statusMenu(for link: Link) -> some View {
        ForEach(["to-read", "to-try", "to-share", "done"], id: \.self) { status in
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

    @ViewBuilder
    func contextMenu(for link: Link) -> some View {
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

    func statusIcon(_ status: String) -> String {
        switch status {
        case "to-read": return "book"
        case "to-try": return "hammer"
        case "to-share": return "paperplane"
        case "done": return "checkmark.circle"
        default: return "circle"
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                // Status section
                Section("Status") {
                    Button {
                        vm.selectedStatus = nil
                    } label: {
                        Label("All", systemImage: vm.selectedStatus == nil ? "checkmark" : "tray.full")
                    }
                    statusMenuItem("To Read", value: "to-read", icon: "book")
                    statusMenuItem("To Try", value: "to-try", icon: "hammer")
                    statusMenuItem("To Share", value: "to-share", icon: "paperplane")
                    statusMenuItem("Done", value: "done", icon: "checkmark.circle")
                }

                // Categories section
                if !vm.categories.isEmpty {
                    Section("Category") {
                        Button {
                            vm.selectedCategory = nil
                        } label: {
                            Label("All Categories", systemImage: vm.selectedCategory == nil ? "checkmark" : "folder")
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
                    }
                }

                // Sort section
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

                // Clear
                if vm.hasActiveFilters {
                    Section {
                        Button(role: .destructive) {
                            vm.selectedStatus = nil
                            vm.selectedCategory = nil
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
                Task { await vm.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
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
        // Sign out moved to Profile tab
    }

    func statusMenuItem(_ label: String, value: String, icon: String) -> some View {
        Button {
            vm.selectedStatus = vm.selectedStatus == value ? nil : value
        } label: {
            Label {
                Text(label)
            } icon: {
                Image(systemName: vm.selectedStatus == value ? "checkmark" : icon)
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
        } else if vm.hasActiveFilters {
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
