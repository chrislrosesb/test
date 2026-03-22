import SwiftUI

struct DigestView: View {
    @Environment(LibraryViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var selectedLink: Link? = nil

    var toReadLinks: [Link] {
        vm.allLinks.filter { $0.status == "to-read" }
    }

    var toDoLinks: [Link] {
        vm.allLinks.filter { $0.status == "to-try" }
    }

    var pickedForYou: [Link] {
        // Most recent to-read articles
        Array(toReadLinks.prefix(3))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today's Reading")
                            .font(.largeTitle)
                            .fontWeight(.black)

                        HStack(spacing: 16) {
                            digestStat(count: toReadLinks.count, label: "to read", color: .blue)
                            digestStat(count: toDoLinks.count, label: "to do", color: .orange)
                            digestStat(count: vm.allLinks.filter { $0.status == "done" }.count, label: "done", color: .green)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // Picked for you
                    if !pickedForYou.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Picked for You")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal, 20)

                            ForEach(pickedForYou) { link in
                                ArticleCardView(link: link)
                                    .padding(.horizontal, 16)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedLink = link }
                            }
                        }
                    }

                    // Unsorted articles
                    let unsorted = vm.allLinks.filter {
                        $0.status == nil || ($0.status != "to-read" && $0.status != "to-try" && $0.status != "done")
                    }
                    if !unsorted.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("\(unsorted.count) Unsorted")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal, 20)

                            Text("These articles need a status. Tap to read, swipe to sort.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .fullScreenCover(item: $selectedLink) { link in
            if let idx = pickedForYou.firstIndex(where: { $0.id == link.id }) {
                ArticleReaderContainer(links: pickedForYou, initialIndex: idx, vm: vm)
            }
        }
    }

    func digestStat(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
