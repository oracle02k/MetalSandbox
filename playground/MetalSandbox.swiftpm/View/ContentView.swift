import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack{
            SwiftUIView { MetalView() }
                .frame(width: 320, height: 320, alignment: .top)
            DebugView()
        }
    }
}
