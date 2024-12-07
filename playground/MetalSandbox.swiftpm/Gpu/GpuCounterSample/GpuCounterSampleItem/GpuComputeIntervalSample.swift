import MetalKit

class GpuComputeIntervalSample: GpuCounterSampleItem {
    let consumeBufferIndex:Int = 2
    let counterSampleBuffer: MTLCounterSampleBuffer
    let startIndex:Int
    let groupLabel:String
    let sampleLabel:String
    
    init(
        describe descriptor: MTLComputePassSampleBufferAttachmentDescriptor,
        counterSampleBuffer: MTLCounterSampleBuffer,
        startIndex:Int,
        groupLabel:String,
        sampleLabel:String
    ){
        self.startIndex = startIndex
        self.counterSampleBuffer = counterSampleBuffer
        self.groupLabel = groupLabel
        self.sampleLabel = sampleLabel
        descriptor.sampleBuffer = counterSampleBuffer
        descriptor.startOfEncoderSampleIndex = startIndex + 0
        descriptor.endOfEncoderSampleIndex = startIndex + 1
    }
    
    func resolve()-> GpuCounterSampleReport {
        let resolveRange = startIndex..<(startIndex + consumeBufferIndex)
        guard let sampleData = try? counterSampleBuffer.resolveCounterRange(resolveRange) else {
            return MissCounterSampleReport(label: sampleLabel)
        }
        
        return sampleData.withUnsafeBytes { body in
            let sample = body.bindMemory(to: MTLCounterResultTimestamp.self)
            let start = sample[startIndex + 0].timestamp
            let end = sample[startIndex + 1].timestamp
            
            return ComputeIntervalReport(
                label: sampleLabel, 
                time: Float(end - start)/Float(NSEC_PER_MSEC)
            )
        }
    }
}
