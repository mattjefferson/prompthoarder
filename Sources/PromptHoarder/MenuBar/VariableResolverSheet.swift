import AppKit
import SwiftUI

struct PromptVariable: Identifiable, Hashable {
    let id: String
}

struct VariableResolverSheet: View {
    let prompt: PromptSummary
    let variables: [PromptVariable]
    let onCopy: (String) -> Void
    let onCancel: () -> Void

    @State private var values: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fill Variables")
                .font(.system(size: 16, weight: .semibold))

            ForEach(variables) { variable in
                variableField(for: variable)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                Button("Copy") {
                    copyResolved()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 360)
        .onAppear {
            initializeDefaults()
        }
    }

    private func variableField(for variable: PromptVariable) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(variable.id)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            if isMultiline(variable.id) {
                TextEditor(text: binding(for: variable))
                    .font(.system(size: 12))
                    .frame(height: 70)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
            } else {
                TextField("", text: binding(for: variable))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func binding(for variable: PromptVariable) -> Binding<String> {
        Binding(
            get: { values[variable.id] ?? "" },
            set: { values[variable.id] = $0 }
        )
    }

    private func initializeDefaults() {
        for variable in variables where values[variable.id] == nil {
            values[variable.id] = ""
        }
    }

    private func isMultiline(_ id: String) -> Bool {
        let lower = id.lowercased()
        return lower.contains("context") || lower.contains("content")
    }

    private func copyResolved() {
        let resolver = VariableResolver()
        let resolved = resolver.resolve(content: prompt.content, values: values)
        onCopy(resolved)
    }
}

struct VariableResolver {
    func resolve(content: String, values: [String: String]) -> String {
        var output = content
        for (key, value) in values {
            let pattern = "\\{\\{\\s*" + NSRegularExpression.escapedPattern(for: key) + "\\s*\\}\\}"
            output = output.replacingOccurrences(of: pattern, with: value, options: .regularExpression)
        }
        return output
    }
}
