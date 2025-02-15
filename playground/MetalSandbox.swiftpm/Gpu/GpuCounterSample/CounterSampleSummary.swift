import Foundation

enum CounterSampleType{
case RenderPass
case ComputePass
}

class CounterSampleSummary {
    let id: Int
    let name: String
    let type: CounterSampleType
    let startIndex: Int
    let consumeBufferIndex: Int
    
    init(id: Int, name: String, type: CounterSampleType, startIndex: Int, consumeBufferIndex:Int){
        self.id = id
        self.name = name
        self.type = type
        self.startIndex = startIndex
        self.consumeBufferIndex = consumeBufferIndex
    }
}
