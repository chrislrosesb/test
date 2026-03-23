import SwiftUI
import UserNotifications

@main
struct ReadingListApp: App {
    @State private var authVM = AuthViewModel()
    @State private var showDigest = false
    @State private var deepLinkArticle: Link? = nil
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                if url.scheme == "procrastinate", url.host == "article" {
                    let articleId = url.lastPathComponent
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let link = ContentView.sharedLibraryVM.allLinks.first(where: { $0.id == articleId }) {
                            deepLinkArticle = link
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openDigest)) { _ in
                showDigest = true
            }
            .sheet(isPresented: $showDigest) {
                if authVM.isAuthenticated {
                    DigestView()
                        .environment(ContentView.sharedLibraryVM)
                }
            }
            .fullScreenCover(item: $deepLinkArticle) { link in
                ArticleReaderContainer(
                    links: [link],
                    initialIndex: 0,
                    vm: ContentView.sharedLibraryVM
                )
            }
            #if targetEnvironment(macCatalyst)
            .frame(minWidth: 900, minHeight: 600)
            #endif
        }
        #if targetEnvironment(macCatalyst)
        .commands {
            // Keyboard shortcuts
            CommandGroup(after: .newItem) {
                Button("Refresh Library") {
                    Task { await ContentView.sharedLibraryVM.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandMenu("Reading") {
                Button("Today's Reading") {
                    showDigest = true
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Divider()

                Button("Enrich All") {
                    if #available(iOS 26, *) {
                        Task { await ContentView.sharedLibraryVM.enrichAll() }
                    }
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
        #endif
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let openDigest = Notification.Name("openDigest")
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        #if targetEnvironment(macCatalyst)
        // Configure Mac window
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.title = "Procrastinate"
            if let titlebar = scene.titlebar {
                titlebar.titleVisibility = .visible
                titlebar.toolbarStyle = .unified
            }
            scene.sizeRestrictions?.minimumSize = CGSize(width: 900, height: 600)
        }
        #endif

        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier.hasPrefix("daily-digest") {
            NotificationCenter.default.post(name: .openDigest, object: nil)
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
