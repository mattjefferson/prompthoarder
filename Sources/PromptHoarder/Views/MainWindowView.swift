import AppKit
import SwiftUI

struct MainWindowView: View {
    @State private var selectedSidebarItemId: SidebarItem.ID? = SidebarData.defaultSelectionId
    @State private var selectedPromptId: UUID?
    @State private var searchText = ""

    private var selectedItem: SidebarItem? {
        SidebarData.item(for: selectedSidebarItemId)
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSidebarItemId)
        } content: {
            PromptListView(sidebarItem: selectedItem, selection: $selectedPromptId)
        } detail: {
            if let promptId = selectedPromptId {
                PromptDetailView(promptId: promptId)
            } else {
                ContentUnavailableView("Select a Prompt", systemImage: "doc.text")
                    .padding()
                    .liquidGlassSurface(cornerRadius: 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
            }
            ToolbarItem(placement: .automatic) {
                SearchField(text: $searchText)
            }
            ToolbarItem {
                Button(action: createPrompt) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)),
            with: nil
        )
    }

    private func createPrompt() {}
}
