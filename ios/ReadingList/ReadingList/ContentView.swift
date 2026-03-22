import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var libraryVM = LibraryViewModel()

    var body: some View {
        tabView
            .task { await libraryVM.load() }
    }

    @ViewBuilder
    var tabView: some View {
        if #available(iOS 26, *) {
            tabs.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            tabs
        }
    }

    var tabs: some View {
        TabView {
            Tab("Library", systemImage: "books.vertical") {
                LibraryView()
                    .environment(libraryVM)
                    .environment(authVM)
            }
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                SearchView()
                    .environment(libraryVM)
            }
            Tab("Profile", systemImage: "person.circle") {
                ProfileView()
                    .environment(libraryVM)
                    .environment(authVM)
            }
        }
    }
}
