import Foundation

enum GpuCounterSampleType {
    case RenderPass
    case ComputePass
}

class GpuCounterSampleSummary {
    let id: Int
    let name: String
    let type: GpuCounterSampleType
    let startIndex: Int
    let consumeBufferIndex: Int
    
    init(id: Int, name: String, type: GpuCounterSampleType, startIndex: Int, consumeBufferIndex: Int) {
        self.id = id
        self.name = name
        self.type = type
        self.startIndex = startIndex
        self.consumeBufferIndex = consumeBufferIndex
    }
}
