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
    @State private var isReaderMode = false  // Default to website view

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
        VStack(spacing: 0) {
            // Content — fills available space
            readerContent
                .gesture(swipeGesture)

            // Bottom toolbar — always visible, flat, edge-to-edge
            bottomBar
        }
        .ignoresSafeArea(edges: .top)
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
                .id(currentLink.id + "reader")
            } else {
                WebView(url: webURL)
                    .id(currentLink.id + "web")
            }
        } else {
            ContentUnavailableView("Invalid URL", systemImage: "link.badge.plus")
        }
    }

    // MARK: - Bottom Bar (flat, edge-to-edge)

    var bottomBar: some View {
        HStack(spacing: 0) {
            // Close
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Article counter
            Text("\(currentIndex + 1) / \(links.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Reader toggle
            Button {
                withAnimation(.spring(duration: 0.3)) { isReaderMode.toggle() }
            } label: {
                Image(systemName: isReaderMode ? "globe" : "doc.text")
                    .font(.system(size: 16))
                    .frame(width: 44, height: 44)
            }

            // Typography (only in reader mode)
            if isReaderMode {
                Button { showTypography = true } label: {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 15))
                        .frame(width: 44, height: 44)
                }
            }

            // Info
            Button { showInfo = true } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .frame(width: 44, height: 44)
            }

            // Overflow
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
                    .font(.system(size: 16))
                    .frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
        .background(.regularMaterial)
    }

    // MARK: - Swipe Gesture

    var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) else { return }

                if horizontal < -50 && currentIndex < links.count - 1 {
                    withAnimation(.spring(duration: 0.3)) { currentIndex += 1 }
                } else if horizontal > 50 && currentIndex > 0 {
                    withAnimation(.spring(duration: 0.3)) { currentIndex -= 1 }
                }
            }
    }
}
