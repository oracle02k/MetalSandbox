import MetalKit

class GpuRenderIntervalSample: GpuCounterSampleItem {
    let consumeBufferIndex: Int = 4
    let counterSampleBuffer: MTLCounterSampleBuffer
    let startIndex: Int
    let groupLabel: String
    let sampleLabel: String

    init(
        describe descriptor: MTLRenderPassSampleBufferAttachmentDescriptor,
        counterSampleBuffer: MTLCounterSampleBuffer,
        startIndex: Int,
        groupLabel: String,
        sampleLabel: String
    ) {
        self.startIndex = startIndex
        self.counterSampleBuffer = counterSampleBuffer
        self.groupLabel = groupLabel
        self.sampleLabel = sampleLabel
        descriptor.sampleBuffer = counterSampleBuffer
        descriptor.startOfVertexSampleIndex = startIndex + 0
        descriptor.endOfVertexSampleIndex = startIndex + 1
        descriptor.startOfFragmentSampleIndex = startIndex + 2
        descriptor.endOfFragmentSampleIndex = startIndex + 3
    }

    func resolve() -> any GpuCounterSampleReport {
        let resolveRange = startIndex..<(startIndex + consumeBufferIndex)
        guard let sampleData = try? counterSampleBuffer.resolveCounterRange(resolveRange) else {
            return MissCounterSampleReport(label: sampleLabel)
        }

        return sampleData.withUnsafeBytes { body in
            let sample = body.bindMemory(to: MTLCounterResultTimestamp.self)
            let vstart = sample[startIndex + 0].timestamp
            let vend = sample[startIndex + 1].timestamp
            let fstart = sample[startIndex + 2].timestamp
            let fend = sample[startIndex + 3].timestamp
            let vertexTime =  Float(vend - vstart)/Float(NSEC_PER_MSEC)
            let fragmentTime = Float(fend - fstart)/Float(NSEC_PER_MSEC)

            return RenderIntervalReport(
                label: sampleLabel,
                vertexTime: vertexTime,
                fragmentTime: fragmentTime
            )
        }
    }
}
