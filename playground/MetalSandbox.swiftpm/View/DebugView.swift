import SwiftUI

struct DebugView: View {
    @ObservedObject private var content = System.shared.debugVM
    
    var body: some View {
        VStack {
            Group {
                Text("GPU Time(ms): \(content.gpuTime*1000)")
                    .frame(alignment: .leading)
                Text("View Width: \(content.viewWidth)")
                    .frame(alignment: .leading)
                Text("View Height: \(content.viewHeight)")
                    .frame(alignment: .leading)
            }
            Spacer()
        }
    }
}
