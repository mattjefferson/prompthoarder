import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(LibraryViewModel.self) private var viewModel
    @FocusState private var searchFocused: Bool
    @State private var searchQuery = ""
    @State private var selectedTab: MenuBarTab = .favorites
    @State private var selectedIndex = 0

    private var results: [PromptSummary] {
        var prompts = viewModel.allPrompts
        switch selectedTab {
        case .favorites:
            prompts = prompts.filter { $0.isFavorite }
        case .recent:
            let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
            prompts = prompts.filter { $0.updatedAt >= cutoff }
        case .workflows:
            prompts = prompts.filter { !$0.workflowIds.isEmpty }
        }

        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let query = trimmed.lowercased()
            prompts = prompts.filter { prompt in
                if prompt.title.lowercased().contains(query) { return true }
                return prompt.tags.contains { $0.name.lowercased().contains(query) }
            }
        }

        return prompts.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            Divider()

            tabBar

            Divider()

            resultsList

            Divider()

            footer
        }
        .padding(12)
        .liquidGlassSurface(cornerRadius: 16, interactive: true)
        .frame(width: 360, height: 420)
        .onAppear {
            searchFocused = true
        }
        .onChange(of: results) { _, _ in
            selectedIndex = min(selectedIndex, max(results.count - 1, 0))
        }
        .onKeyPress(.downArrow) {
            guard !results.isEmpty else { return .handled }
            selectedIndex = min(selectedIndex + 1, results.count - 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            guard !results.isEmpty else { return .handled }
            selectedIndex = max(selectedIndex - 1, 0)
            return .handled
        }
        .onKeyPress(.return) {
            guard results.indices.contains(selectedIndex) else { return .handled }
            viewModel.incrementUsage(id: results[selectedIndex].id)
            return .handled
        }
        .onKeyPress(.escape) {
            NSApp.keyWindow?.performClose(nil)
            return .handled
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search prompts...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold))
                .focused($searchFocused)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(MenuBarTab.allCases) { tab in
                MenuBarTabButton(
                    title: tab.title,
                    systemImage: tab.systemImage,
                    isSelected: selectedTab == tab
                ) {
                    selectedTab = tab
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var resultsList: some View {
        Group {
            if results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 20, weight: .semibold))
                    Text("No matches")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, prompt in
                            MenuBarResultRowView(prompt: prompt, isSelected: index == selectedIndex)
                                .id(prompt.id)
                                .onTapGesture {
                                    selectedIndex = index
                                }
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: selectedIndex) { _, _ in
                        guard results.indices.contains(selectedIndex) else { return }
                        proxy.scrollTo(results[selectedIndex].id, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            Button("Open Library") {
                openMainWindow()
            }
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .font(.system(size: 12, weight: .medium))
        .buttonStyle(.bordered)
        .padding(.top, 6)
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.isVisible }?.makeKeyAndOrderFront(nil)
    }
}

private enum MenuBarTab: CaseIterable, Identifiable {
    case favorites
    case recent
    case workflows

    var id: String { title }

    var title: String {
        switch self {
        case .favorites: return "Favorites"
        case .recent: return "Recent"
        case .workflows: return "Workflows"
        }
    }

    var systemImage: String {
        switch self {
        case .favorites: return "star"
        case .recent: return "clock"
        case .workflows: return "arrow.triangle.branch"
        }
    }
}

private struct MenuBarTabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct MenuBarResultRowView: View {
    let prompt: PromptSummary
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(prompt.title)
                    .font(.system(size: 13, weight: .semibold))
                if prompt.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.yellow)
                }
                Spacer()
            }

            if !prompt.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(prompt.tags.prefix(2)) { tag in
                        Text(tag.name)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
    }
}
