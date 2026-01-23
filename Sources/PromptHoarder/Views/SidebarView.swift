import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem.ID?

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarData.groups) { group in
                Section(group.title) {
                    ForEach(group.items) { item in
                        Label(item.title, systemImage: item.systemImage)
                            .tag(item.id as SidebarItem.ID?)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

struct SidebarItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case library
        case category
        case tag
        case workflow
    }

    let id: String
    let title: String
    let systemImage: String
    let kind: Kind
}

struct SidebarGroup: Identifiable {
    let id: String
    let title: String
    let items: [SidebarItem]
}

enum SidebarData {
    static let groups: [SidebarGroup] = [
        SidebarGroup(
            id: "library",
            title: "Library",
            items: [
                SidebarItem(id: "all-prompts", title: "All Prompts", systemImage: "tray.full", kind: .library),
                SidebarItem(id: "favorites", title: "Favorites", systemImage: "star", kind: .library),
                SidebarItem(id: "recent", title: "Recent", systemImage: "clock", kind: .library),
            ]
        ),
        SidebarGroup(
            id: "categories",
            title: "Categories",
            items: [
                SidebarItem(id: "category-writing", title: "Writing", systemImage: "pencil", kind: .category),
                SidebarItem(id: "category-engineering", title: "Engineering", systemImage: "hammer", kind: .category),
                SidebarItem(id: "category-research", title: "Research", systemImage: "magnifyingglass", kind: .category),
            ]
        ),
        SidebarGroup(
            id: "tags",
            title: "Tags",
            items: [
                SidebarItem(id: "tag-swift", title: "Swift", systemImage: "swift", kind: .tag),
                SidebarItem(id: "tag-release", title: "Release", systemImage: "bolt", kind: .tag),
                SidebarItem(id: "tag-design", title: "Design", systemImage: "paintpalette", kind: .tag),
            ]
        ),
        SidebarGroup(
            id: "workflows",
            title: "Workflows",
            items: [
                SidebarItem(id: "workflow-release", title: "Release Checklist", systemImage: "checklist", kind: .workflow),
                SidebarItem(id: "workflow-interview", title: "Interview Prep", systemImage: "person.text.rectangle", kind: .workflow),
            ]
        ),
    ]

    static let defaultSelectionId: SidebarItem.ID? = groups.first?.items.first?.id

    static func item(for id: SidebarItem.ID?) -> SidebarItem? {
        guard let id else { return nil }
        for group in groups {
            if let item = group.items.first(where: { $0.id == id }) {
                return item
            }
        }
        return nil
    }
}
