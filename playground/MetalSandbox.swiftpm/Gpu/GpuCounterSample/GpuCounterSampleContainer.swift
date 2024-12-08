import MetalKit

class GpuCounterSampleContainer {
    let gpu: GpuContext
    let sampleItemRepository: GpuCounterSampleItemRepository
    var sampleIndex = 0
    lazy var counterSampleBuffer: MTLCounterSampleBuffer = uninitialized()

    init(gpu: GpuContext, sampleItemRepository: GpuCounterSampleItemRepository) {
        self.gpu = gpu
        self.sampleItemRepository = sampleItemRepository
    }

    func build(sampleBufferSize: Int) {
        sampleItemRepository.deleteAll()
        counterSampleBuffer = gpu.makeCounterSampleBuffer(MTLCommonCounterSet.timestamp, sampleBufferSize)!
        sampleIndex = 0
    }

    func resolve(groupLabel: String) -> [GpuCounterSampleReport] {
        return sampleItemRepository.fetch(groupLabel: groupLabel).map { item in
            return item.resolve()
        }
    }

    func addSampleRenderInterval(
        of descriptor: MTLRenderPassDescriptor,
        index: Int,
        groupLabel: String,
        sampleLabel: String
    ) -> Bool {
        guard let sampleAttachment = descriptor.sampleBufferAttachments[index] else {
            // appFatalError("sample buffer error.")
            return false
        }

        addSampleItem(GpuRenderIntervalSample(
            describe: sampleAttachment,
            counterSampleBuffer: counterSampleBuffer,
            startIndex: sampleIndex,
            groupLabel: groupLabel,
            sampleLabel: sampleLabel
        ))

        return true
    }

    func addSampleComputeInterval(
        of descriptor: MTLComputePassDescriptor,
        index: Int,
        groupLabel: String,
        sampleLabel: String
    ) -> Bool {
        guard let sampleAttachment = descriptor.sampleBufferAttachments[index] else {
            return false
        }

        addSampleItem(GpuComputeIntervalSample(
            describe: sampleAttachment,
            counterSampleBuffer: counterSampleBuffer,
            startIndex: sampleIndex,
            groupLabel: groupLabel,
            sampleLabel: sampleLabel
        ))

        return true
    }

    private func addSampleItem(_ item: GpuCounterSampleItem) {
        sampleIndex += item.consumeBufferIndex
        sampleItemRepository.persist(item)
    }
}
