import MetalKit

class CounterSampler {
    let counterSampleSummaryRepository: CounterSampleSummaryRepository
    let counterSampleReportRepository: CounterSampleReportRepository
    
    var sampleIndex = 0
    lazy var counterSampleBuffer: MTLCounterSampleBuffer = uninitialized()
    
    init(
        counterSampleSummaryRepository: CounterSampleSummaryRepository,
        counterSampleReportRepository: CounterSampleReportRepository
    ) {
        self.counterSampleSummaryRepository = counterSampleSummaryRepository
        self.counterSampleReportRepository = counterSampleReportRepository
    }
    
    func build(counterSampleBuffer: MTLCounterSampleBuffer) {
        self.counterSampleBuffer = counterSampleBuffer
        counterSampleSummaryRepository.deleteAll()
        counterSampleReportRepository.deleteAll()
        sampleIndex = 0
    }
    
    func resolve(frame:UInt64) {
        let resolveRange = 0..<sampleIndex
        guard let sampleData = try? counterSampleBuffer.resolveCounterRange(resolveRange) else {
            return 
        }
        
        sampleData.withUnsafeBytes { body in
            let sample = body.bindMemory(to: MTLCounterResultTimestamp.self)
            for summary in counterSampleSummaryRepository.fetchAll() {
                switch summary.type {
                case .RenderPass: resolveRenderPass(frame: frame, summary: summary, sample: sample)
                case .ComputePass: resolveComputePass(frame: frame, summary: summary, sample: sample)
                }
            }
        }
    }
    
    private func resolveRenderPass(
        frame:UInt64,
        summary: CounterSampleSummary,
        sample:UnsafeBufferPointer<MTLCounterResultTimestamp>
    ){
        let startIndex = summary.startIndex
        let vstart = sample[startIndex + 0].timestamp
        let vend = sample[startIndex + 1].timestamp
        let fstart = sample[startIndex + 2].timestamp
        let fend = sample[startIndex + 3].timestamp
        let vertexTime =  Float(vend - vstart)/Float(NSEC_PER_MSEC)
        let fragmentTime = Float(fend - fstart)/Float(NSEC_PER_MSEC)
        
        counterSampleReportRepository.persist([
            CounterSampleReport(counterSampleId: summary.id, frame:frame, type: .VertexTime, interval: vertexTime),
            CounterSampleReport(counterSampleId: summary.id, frame:frame,type: .FragmentTime, interval: fragmentTime)
        ])
    }
    
    private func resolveComputePass(
        frame:UInt64,
        summary:CounterSampleSummary,
        sample:UnsafeBufferPointer<MTLCounterResultTimestamp>
    ){
        let startIndex = summary.startIndex
        let start = sample[startIndex + 0].timestamp
        let end = sample[startIndex + 1].timestamp
        let time = Float(end - start)/Float(NSEC_PER_MSEC)
        
        counterSampleReportRepository.persist(
            CounterSampleReport(counterSampleId: summary.id, frame:frame, type: .ComputeTime, interval: time)
        )
    }
    
    func attachToRenderPass(
        descriptor: MTLRenderPassSampleBufferAttachmentDescriptor,
        name: String
    ) {
        descriptor.sampleBuffer = counterSampleBuffer
        descriptor.startOfVertexSampleIndex = sampleIndex + 0
        descriptor.endOfVertexSampleIndex = sampleIndex + 1
        descriptor.startOfFragmentSampleIndex = sampleIndex + 2
        descriptor.endOfFragmentSampleIndex = sampleIndex + 3
        
        let summary = CounterSampleSummary(
            id: counterSampleSummaryRepository.count(),
            name: name, 
            type: .RenderPass,
            startIndex: sampleIndex,
            consumeBufferIndex: 4
        )
        
        counterSampleSummaryRepository.persist(summary)
        sampleIndex += 4
    }
    
    func attachToComputePass(
        descriptor: MTLComputePassSampleBufferAttachmentDescriptor,
        name: String
    ) {
        descriptor.sampleBuffer = counterSampleBuffer
        descriptor.startOfEncoderSampleIndex = sampleIndex + 0
        descriptor.endOfEncoderSampleIndex = sampleIndex + 1
        
        let summary = CounterSampleSummary(
            id: counterSampleSummaryRepository.count(),
            name: name, 
            type: .ComputePass,
            startIndex: sampleIndex,
            consumeBufferIndex: 2
        )
        
        counterSampleSummaryRepository.persist(summary)
        sampleIndex += 2
    }
}
