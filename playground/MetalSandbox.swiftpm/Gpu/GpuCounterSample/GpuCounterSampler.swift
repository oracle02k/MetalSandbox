import MetalKit

class GpuCounterSampler {
    let counterSampleContainer: GpuCounterSampleContainer

    init (counterSampleContainer: GpuCounterSampleContainer) {
        self.counterSampleContainer = counterSampleContainer
    }

    func build() {
        counterSampleContainer.build(sampleBufferSize: 32)
    }

    func makeGroup(groupLabel: String) -> GpuCounterSampleGroup {
        let group = GpuCounterSampleGroup(
            label: groupLabel,
            container: counterSampleContainer
        )
        return group
    }
}
