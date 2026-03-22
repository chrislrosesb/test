import SwiftUI

struct FilterSheetView: View {
    @Environment(LibraryViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    private let statuses: [(label: String, value: String?)] = [
        ("All", nil), ("To Read", "to-read"), ("To Try", "to-try"),
        ("To Share", "to-share"), ("Done", "done")
    ]

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            List {
                statusSection
                if !vm.categories.isEmpty { categorySection }
                sortSection
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if vm.hasActiveFilters {
                        Button("Clear All") {
                            vm.selectedStatus = nil
                            vm.selectedCategory = nil
                            vm.sortByStars = false
                        }
                        .foregroundStyle(.red)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    var statusSection: some View {
        Section("Status") {
            ForEach(statuses, id: \.label) { item in
                statusRow(label: item.label, value: item.value)
            }
        }
    }

    var categorySection: some View {
        Section("Category") {
            categoryRow(name: "All Categories", value: nil)
            ForEach(vm.categories) { cat in
                categoryRow(name: cat.name, value: cat.name)
            }
        }
    }

    var sortSection: some View {
        Section("Sort") {
            sortRow(label: "Newest First", icon: "clock", isSelected: !vm.sortByStars) {
                vm.sortByStars = false
            }
            sortRow(label: "Highest Rated", icon: "star.fill", isSelected: vm.sortByStars) {
                vm.sortByStars = true
            }
        }
    }

    func statusRow(label: String, value: String?) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { vm.selectedStatus = value }
        } label: {
            HStack {
                Group {
                    if let v = value {
                        Image(systemName: StatusBadge(status: v).icon)
                            .foregroundStyle(StatusPill(status: v).color)
                    } else {
                        Image(systemName: "tray.full").foregroundStyle(.secondary)
                    }
                }
                .frame(width: 20)
                Text(label).foregroundStyle(.primary)
                Spacer()
                if vm.selectedStatus == value {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor).fontWeight(.semibold)
                }
            }
        }
    }

    func categoryRow(name: String, value: String?) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { vm.selectedCategory = value }
        } label: {
            HStack {
                Text(name).foregroundStyle(.primary)
                Spacer()
                if vm.selectedCategory == value {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor).fontWeight(.semibold)
                }
            }
        }
    }

    func sortRow(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).foregroundStyle(.secondary).frame(width: 20)
                Text(label).foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor).fontWeight(.semibold)
                }
            }
        }
    }
}
