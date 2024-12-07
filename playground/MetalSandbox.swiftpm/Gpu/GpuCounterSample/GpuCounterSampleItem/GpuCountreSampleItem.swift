import MetalKit

protocol GpuCounterSampleItem {
    var consumeBufferIndex: Int { get }
    var groupLabel: String { get }
    var sampleLabel: String { get }
    func resolve() -> any GpuCounterSampleReport
}
