import MetalKit

class GpuCounterSampler {
    let counterSampleSummaryRepository: GpuCounterSampleSummaryRepository
    let counterSampleReportRepository: GpuCounterSampleReportRepository

    var sampleIndex = 0
    lazy var counterSampleBuffer: MTLCounterSampleBuffer = uninitialized()

    init(
        counterSampleSummaryRepository: GpuCounterSampleSummaryRepository,
        counterSampleReportRepository: GpuCounterSampleReportRepository
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

    func resolve(frame: UInt64) {
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
                case .BlitPass: resolveBlitPass(frame: frame, summary: summary, sample: sample)
                }
            }
        }
    }

    private func resolveRenderPass(
        frame: UInt64,
        summary: GpuCounterSampleSummary,
        sample: UnsafeBufferPointer<MTLCounterResultTimestamp>
    ) {
        let startIndex = summary.startIndex
        let vstart = sample[startIndex + 0].timestamp
        let vend = sample[startIndex + 1].timestamp
        let fstart = sample[startIndex + 2].timestamp
        let fend = sample[startIndex + 3].timestamp
        let vertexTime =  Float(vend - vstart)/Float(NSEC_PER_MSEC)
        let fragmentTime = Float(fend - fstart)/Float(NSEC_PER_MSEC)

        counterSampleReportRepository.persist([
            GpuCounterSampleReport(counterSampleId: summary.id, frame: frame, type: .VertexTime, interval: vertexTime),
            GpuCounterSampleReport(counterSampleId: summary.id, frame: frame, type: .FragmentTime, interval: fragmentTime)
        ])
    }

    private func resolveComputePass(
        frame: UInt64,
        summary: GpuCounterSampleSummary,
        sample: UnsafeBufferPointer<MTLCounterResultTimestamp>
    ) {
        let startIndex = summary.startIndex
        let start = sample[startIndex + 0].timestamp
        let end = sample[startIndex + 1].timestamp
        let time = Float(end - start)/Float(NSEC_PER_MSEC)

        counterSampleReportRepository.persist(
            GpuCounterSampleReport(counterSampleId: summary.id, frame: frame, type: .ComputeTime, interval: time)
        )
    }
    
    private func resolveBlitPass(
        frame: UInt64,
        summary: GpuCounterSampleSummary,
        sample: UnsafeBufferPointer<MTLCounterResultTimestamp>
    ) {
        let startIndex = summary.startIndex
        let start = sample[startIndex + 0].timestamp
        let end = sample[startIndex + 1].timestamp
        let time = Float(end - start)/Float(NSEC_PER_MSEC)

        counterSampleReportRepository.persist(
            GpuCounterSampleReport(counterSampleId: summary.id, frame: frame, type: .BlitTime, interval: time)
        )
    }

    func attachToRenderPass(
        descriptor: MTLRenderPassDescriptor,
        name: String
    ) {
        guard let attachment = descriptor.sampleBufferAttachments[0] else {
            return
        }

        let summary = fetchOrNewCounterSampleSummary(name: name, type: .RenderPass, consumeBufferIndex: 4)

        attachment.sampleBuffer = counterSampleBuffer
        attachment.startOfVertexSampleIndex = summary.startIndex
        attachment.endOfVertexSampleIndex = summary.startIndex + 1
        attachment.startOfFragmentSampleIndex = summary.startIndex + 2
        attachment.endOfFragmentSampleIndex = summary.startIndex + 3
    }

    func attachToComputePass(
        descriptor: MTLComputePassDescriptor,
        name: String
    ) {
        guard let attachment = descriptor.sampleBufferAttachments[0] else {
            return
        }

        let summary = fetchOrNewCounterSampleSummary(name: name, type: .ComputePass, consumeBufferIndex: 2)

        attachment.sampleBuffer = counterSampleBuffer
        attachment.startOfEncoderSampleIndex = summary.startIndex
        attachment.endOfEncoderSampleIndex = summary.startIndex + 1
    }
    
    func attachToBlitPass(
        descriptor: MTLBlitPassDescriptor,
        name: String
    ) {
        guard let attachment = descriptor.sampleBufferAttachments[0] else {
            return
        }

        let summary = fetchOrNewCounterSampleSummary(name: name, type: .BlitPass, consumeBufferIndex: 2)

        attachment.sampleBuffer = counterSampleBuffer
        attachment.startOfEncoderSampleIndex = summary.startIndex
        attachment.endOfEncoderSampleIndex = summary.startIndex + 1
    }

    private func fetchOrNewCounterSampleSummary(name: String, type: GpuCounterSampleType, consumeBufferIndex: Int) -> GpuCounterSampleSummary {
        return counterSampleSummaryRepository.first(name) ?? {
            let summary = GpuCounterSampleSummary(
                id: counterSampleSummaryRepository.count(),
                name: name,
                type: type,
                startIndex: sampleIndex,
                consumeBufferIndex: consumeBufferIndex
            )
            counterSampleSummaryRepository.persist(summary)
            sampleIndex += consumeBufferIndex
            return summary
        }()
    }
}
