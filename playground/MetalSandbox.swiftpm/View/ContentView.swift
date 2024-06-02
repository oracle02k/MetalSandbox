import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading) {
            SwiftUIView { MetalView() }
                .frame(width: 320, height: 320, alignment: .top)
            DebugView()
        }
    }
}
