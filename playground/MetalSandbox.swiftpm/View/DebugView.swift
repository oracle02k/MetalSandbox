import SwiftUI

struct DebugView: View {
    @ObservedObject private var content = System.shared.debugVM
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("GPU Time(ms): \(content.gpuTime*1000)")
            Text("View Width: \(content.viewWidth)")
            Text("View Height: \(content.viewHeight)")
            Text("Logs:")
            Text(content.log)
            Spacer()
        }
    }
}
