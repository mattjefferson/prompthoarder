import SwiftUI

struct PromptDetailView: View {
    let promptId: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prompt Detail")
                .font(.system(size: 22, weight: .semibold))
            Text("Placeholder content for \(promptId.uuidString)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .liquidGlassSurface(cornerRadius: 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}
