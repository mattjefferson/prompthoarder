import SwiftUI

struct SearchField: View {
    @Binding var text: String

    var body: some View {
        TextField("Search", text: $text)
            .textFieldStyle(.roundedBorder)
            .frame(width: 220)
    }
}
