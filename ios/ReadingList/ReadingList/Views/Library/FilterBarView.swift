import SwiftUI

struct FilterBarView: View {
    @Environment(LibraryViewModel.self) private var vm

    private let statuses: [(label: String, value: String?)] = [
        ("All", nil),
        ("To Read", "to-read"),
        ("To Try", "to-try"),
        ("To Share", "to-share"),
        ("Done", "done")
    ]

    var body: some View {
        @Bindable var vm = vm
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Status chips
                ForEach(statuses, id: \.label) { item in
                    FilterChip(
                        label: item.label,
                        isSelected: vm.selectedStatus == item.value,
                        color: item.value.map { StatusPill(status: $0).color } ?? .primary
                    ) {
                        withAnimation(.spring(duration: 0.3, bounce: 0.4)) {
                            vm.selectedStatus = item.value
                        }
                    }
                }

                Divider().frame(height: 20)

                // Category chips
                ForEach(vm.categories) { cat in
                    FilterChip(
                        label: cat.name,
                        isSelected: vm.selectedCategory == cat.name,
                        color: .indigo
                    ) {
                        withAnimation(.spring(duration: 0.3, bounce: 0.4)) {
                            vm.selectedCategory = vm.selectedCategory == cat.name ? nil : cat.name
                        }
                    }
                }

                Divider().frame(height: 20)

                // Sort
                FilterChip(
                    label: "★ Stars",
                    isSelected: vm.sortByStars,
                    color: .yellow
                ) {
                    withAnimation(.spring(duration: 0.3, bounce: 0.4)) {
                        vm.sortByStars.toggle()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isSelected
                        ? color.opacity(0.18)
                        : Color(.systemGray6)
                )
                .foregroundStyle(isSelected ? color : .primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? color.opacity(0.5) : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
