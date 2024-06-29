import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading) {
        //    SwiftUIView { MetalView() }
            SwiftUIView { MetalView() }
                .frame(minWidth: 380, minHeight: 380)
                .aspectRatio(CGSize(width: 1, height: 1), contentMode: .fit)
            DebugView()
        }
    }
}
