import SwiftUI

struct DebugView: View {
    @ObservedObject private var content: DebugVM
    @State private var selectionPipeline: Application.Pipeline

    init() {
        content = DIContainer.resolve(DebugVM.self)
        selectionPipeline = .TriangleRender
    }

    var body: some View {
        VStack(alignment: .leading) {
            Picker(selection: $selectionPipeline, label: Text("Pipeline")) {
                ForEach(Application.Pipeline.allCases, id: \.self) { (pipeline) in
                    Text(pipeline.rawValue).tag(pipeline)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectionPipeline) { newValue in
                print("changet to \(newValue)")
                content.changePipeline(pipeline: newValue)
            }
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
