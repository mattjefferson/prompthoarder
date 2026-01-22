import AppKit
import SwiftUI

struct MenuBarView: View {
    var body: some View {
        VStack {
            Text("Menu Bar Placeholder")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .frame(width: 300)
        .padding()
    }
}
