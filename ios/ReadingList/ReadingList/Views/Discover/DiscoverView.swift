import SwiftUI

struct DiscoverView: View {
    @Environment(LibraryViewModel.self) private var vm
    @Environment(AuthViewModel.self) private var authVM

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: LibraryInsightsView().environment(vm)) {
                        DiscoverRow(title: "Library Insights",
                                    subtitle: "Analytics about your reading habits",
                                    icon: "chart.bar.xaxis.ascending.badge.clock",
                                    color: .orange)
                    }
                    NavigationLink(destination: NotesReviewView().environment(vm)) {
                        DiscoverRow(title: "Notes Review",
                                    subtitle: "Review and synthesise your annotations",
                                    icon: "note.text",
                                    color: .green)
                    }
                    NavigationLink(destination: KnowledgeSynthesisView().environment(vm)) {
                        DiscoverRow(title: "Knowledge Synthesis",
                                    subtitle: "AI patterns across your reading",
                                    icon: "brain",
                                    color: .purple)
                    }
                } header: {
                    Text("Intelligence")
                }

                Section {
                    NavigationLink(destination: SourcesView().environment(vm)) {
                        DiscoverRow(title: "Sources",
                                    subtitle: "Browse articles by publisher",
                                    icon: "globe",
                                    color: .blue)
                    }
                } header: {
                    Text("Sources")
                }
            }
            .navigationTitle("Discover")
        }
    }
}

private struct DiscoverRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
