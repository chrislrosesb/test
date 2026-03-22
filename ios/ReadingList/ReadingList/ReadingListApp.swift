import SwiftUI

@main
struct ReadingListApp: App {
    @State private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.isAuthenticated {
                    ContentView()
                        .environment(authVM)
                } else {
                    SignInView()
                        .environment(authVM)
                }
            }
            .animation(.spring(duration: 0.5, bounce: 0.3), value: authVM.isAuthenticated)
        }
    }
}
