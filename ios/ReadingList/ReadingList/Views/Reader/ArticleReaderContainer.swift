import SwiftUI

/// Full-screen immersive reader with swipe navigation between articles.
struct ArticleReaderContainer: View {
    let links: [Link]
    let initialIndex: Int
    let vm: LibraryViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int
    @State private var showInfo = false
    @State private var showTypography = false
    @State private var isReaderMode = true
    @State private var showToolbar = true

    @AppStorage("readerFontSize") private var fontSize: Double = 17
    @AppStorage("readerFont") private var fontRaw: String = "system"
    @AppStorage("readerTheme") private var themeRaw: String = "dark"

    init(links: [Link], initialIndex: Int, vm: LibraryViewModel) {
        self.links = links
        self.initialIndex = initialIndex
        self.vm = vm
        self._currentIndex = State(initialValue: initialIndex)
    }

    var currentLink: Link {
        links[min(currentIndex, links.count - 1)]
    }

    var font: ReaderFont { ReaderFont(rawValue: fontRaw) ?? .system }
    var theme: ReaderTheme { ReaderTheme(rawValue: themeRaw) ?? .dark }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Reader content — full screen
            readerContent
                .ignoresSafeArea(edges: .bottom)
                .gesture(swipeGesture)
                .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { showToolbar.toggle() } }

            // Floating toolbar
            if showToolbar {
                floatingToolbar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .statusBarHidden(!showToolbar)
        .animation(.easeOut(duration: 0.2), value: showToolbar)
        .sheet(isPresented: $showInfo) {
            ArticleDetailView(link: currentLink)
                .environment(vm)
        }
        .sheet(isPresented: $showTypography) {
            TypographySheet()
        }
    }

    // MARK: - Reader Content

    @ViewBuilder
    var readerContent: some View {
        if let webURL = URL(string: currentLink.url) {
            if isReaderMode {
                ReaderWebView(
                    url: webURL,
                    fontSize: fontSize,
                    font: font,
                    theme: theme,
                    onFallback: { withAnimation { isReaderMode = false } }
                )
                .id(currentLink.id + "reader") // Force reload on article change
            } else {
                WebView(url: webURL)
                    .id(currentLink.id + "web")
            }
        } else {
            ContentUnavailableView("Invalid URL", systemImage: "link.badge.plus")
        }
    }

    // MARK: - Floating Toolbar

    var floatingToolbar: some View {
        HStack(spacing: 20) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
            }

            Spacer()

            // Article position
            Text("\(currentIndex + 1) / \(links.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if isReaderMode {
                Button { showTypography = true } label: {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 14))
                }
            }

            Button {
                withAnimation(.spring(duration: 0.3)) { isReaderMode.toggle() }
            } label: {
                Image(systemName: isReaderMode ? "globe" : "doc.text")
                    .font(.system(size: 14))
            }

            Button { showInfo = true } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
            }

            Menu {
                Button {
                    guard let url = URL(string: currentLink.url) else { return }
                    UIApplication.shared.open(url)
                } label: {
                    Label("Open in Safari", systemImage: "safari")
                }
                Button {
                    UIPasteboard.general.string = currentLink.url
                } label: {
                    Label("Copy URL", systemImage: "doc.on.doc")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Swipe Gesture

    var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                // Only handle horizontal swipes (not vertical scrolling)
                guard abs(horizontal) > abs(vertical) else { return }

                if horizontal < -50 && currentIndex < links.count - 1 {
                    // Swipe left → next article
                    withAnimation(.spring(duration: 0.3)) { currentIndex += 1 }
                    isReaderMode = true
                } else if horizontal > 50 && currentIndex > 0 {
                    // Swipe right → previous article
                    withAnimation(.spring(duration: 0.3)) { currentIndex -= 1 }
                    isReaderMode = true
                }
            }
    }
}
