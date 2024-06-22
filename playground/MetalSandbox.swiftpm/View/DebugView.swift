import SwiftUI

struct DebugView: View {
    @ObservedObject private var content = System.shared.debugVM

    var body: some View {
        VStack(alignment: .leading) {
            Text("Init Logs:")
            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: true) {
                    Text(content.initLog)
                        .multilineTextAlignment(.leading)
                        .frame(width: geometry.size.width, alignment: .leading)
                }
            }
            Text("Frame Logs:")
            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: true) {
                    Text(content.frameLog)
                        .multilineTextAlignment(.leading)
                        .frame(width: geometry.size.width, alignment: .leading)
                }
            }
            Spacer()
        }
    }
}
