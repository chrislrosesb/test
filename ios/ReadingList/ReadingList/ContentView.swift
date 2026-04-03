import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var libraryVM = ContentView.sharedLibraryVM
    @State private var selectedTab = "read"

    static let sharedLibraryVM = LibraryViewModel()

    @State private var achievementStore = AchievementStore.shared

    var body: some View {
        ZStack {
            Group {
                if sizeClass == .regular {
                    iPadLayout
                } else {
                    iPhoneLayout
                }
            }
            .task {
                await libraryVM.load()
                await SubtaskStore.shared.loadAll()
            }

            // Achievement popup — floats above everything
            if let achievement = achievementStore.current {
                AchievementPopupView(achievement: achievement) {
                    achievementStore.dismiss()
                }
                .zIndex(999)
                .transition(.opacity)
            }
        }
    }

    // MARK: - iPhone (TabView)

    @ViewBuilder
    var iPhoneLayout: some View {
        if #available(iOS 26, *) {
            tabs.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            tabs
        }
    }

    var tabs: some View {
        TabView(selection: $selectedTab) {
            Tab("Read", systemImage: "book", value: "read") {
                LibraryView(statusFilter: "to-read")
                    .environment(libraryVM)
                    .environment(authVM)
            }
            Tab("Do", systemImage: "hammer", value: "do") {
                LibraryView(statusFilter: "to-try")
                    .environment(libraryVM)
                    .environment(authVM)
            }
            Tab("Library", systemImage: "books.vertical", value: "library") {
                LibraryView(statusFilter: nil)
                    .environment(libraryVM)
                    .environment(authVM)
            }
            Tab("Discover", systemImage: "sparkles", value: "discover") {
                DiscoverView()
                    .environment(libraryVM)
                    .environment(authVM)
            }
        }
    }

    // MARK: - iPad (NavigationSplitView)

    var iPadLayout: some View {
        iPadSplitView
            .environment(libraryVM)
            .environment(authVM)
    }

    var iPadSplitView: some View {
        IPadNavigationView()
            .environment(libraryVM)
            .environment(authVM)
    }
}
