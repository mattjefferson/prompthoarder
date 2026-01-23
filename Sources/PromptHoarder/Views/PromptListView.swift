import SwiftUI

struct PromptListView: View {
    let sidebarItem: SidebarItem?
    @Binding var selection: UUID?

    private var items: [PromptListItem] {
        switch sidebarItem?.kind {
        case .workflow:
            return workflowItems
        case .category:
            return categoryItems
        case .tag:
            return tagItems
        case .library, .none:
            return libraryItems
        }
    }

    var body: some View {
        List(items, selection: $selection) { item in
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                Text(item.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .tag(item.id)
        }
        .navigationTitle(sidebarItem?.title ?? "Prompts")
    }
}

private struct PromptListItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}

private let libraryItems: [PromptListItem] = [
    PromptListItem(title: "Daily Review", subtitle: "Morning check-in"),
    PromptListItem(title: "Bug Triage", subtitle: "Triage flow"),
    PromptListItem(title: "Release Notes", subtitle: "Draft template"),
    PromptListItem(title: "Meeting Summary", subtitle: "Recap prompt"),
    PromptListItem(title: "Research Outline", subtitle: "Structure notes"),
    PromptListItem(title: "Customer Reply", subtitle: "Support response"),
]

private let categoryItems: [PromptListItem] = [
    PromptListItem(title: "Spec Draft", subtitle: "Product outline"),
    PromptListItem(title: "Technical Brief", subtitle: "Engineering depth"),
    PromptListItem(title: "Study Notes", subtitle: "Research summary"),
]

private let tagItems: [PromptListItem] = [
    PromptListItem(title: "SwiftUI Snippet", subtitle: "Component prompt"),
    PromptListItem(title: "Release Checklist", subtitle: "Ship steps"),
    PromptListItem(title: "Design Critique", subtitle: "UI feedback"),
]

private let workflowItems: [PromptListItem] = [
    PromptListItem(title: "Release Checklist", subtitle: "Step-by-step ship"),
    PromptListItem(title: "Interview Prep", subtitle: "Question loop"),
]
