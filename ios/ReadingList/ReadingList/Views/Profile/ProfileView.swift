import SwiftUI

struct ProfileView: View {
    @Environment(LibraryViewModel.self) private var vm
    @Environment(AuthViewModel.self) private var authVM

    @AppStorage("libraryViewMode") private var viewMode: String = "cards"
    @AppStorage("readerFontSize") private var fontSize: Double = 17
    @AppStorage("readerFont") private var fontRaw: String = "system"
    @AppStorage("readerTheme") private var themeRaw: String = "dark"

    var body: some View {
        NavigationStack {
            List {
                statsSection
                readerSection
                librarySection
                accountSection
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Stats

    var statsSection: some View {
        Section("Reading Stats") {
            statRow(icon: "books.vertical", label: "Total Articles", value: "\(vm.allLinks.count)")
            statRow(icon: "checkmark.circle", label: "Done", value: "\(vm.allLinks.filter { $0.status == "done" }.count)")
            statRow(icon: "book", label: "To Read", value: "\(vm.allLinks.filter { $0.status == "to-read" }.count)")
            statRow(icon: "star.fill", label: "Avg Rating", value: averageRating)
            statRow(icon: "folder", label: "Categories", value: "\(vm.categories.count)")
        }
    }

    var averageRating: String {
        let rated = vm.allLinks.compactMap(\.stars).filter { $0 > 0 }
        guard !rated.isEmpty else { return "—" }
        let avg = Double(rated.reduce(0, +)) / Double(rated.count)
        return String(format: "%.1f", avg)
    }

    func statRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Reader Settings

    var readerSection: some View {
        Section("Reader") {
            HStack {
                Text("Font Size")
                Spacer()
                Text("\(Int(fontSize))pt")
                    .foregroundStyle(.secondary)
                Stepper("", value: $fontSize, in: 13...24, step: 1)
                    .labelsHidden()
                    .frame(width: 100)
            }
            Picker("Font", selection: $fontRaw) {
                Text("System").tag("system")
                Text("Serif").tag("serif")
                Text("Mono").tag("mono")
            }
            Picker("Theme", selection: $themeRaw) {
                Text("Dark").tag("dark")
                Text("Light").tag("light")
                Text("Sepia").tag("sepia")
            }
        }
    }

    // MARK: - Library Settings

    var librarySection: some View {
        Section("Library") {
            Picker("Default View", selection: $viewMode) {
                Text("Cards").tag("cards")
                Text("List").tag("list")
            }
        }
    }

    // MARK: - Account

    var accountSection: some View {
        Section {
            Button(role: .destructive) {
                authVM.signOut()
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                    Spacer()
                }
            }
        }
    }
}
