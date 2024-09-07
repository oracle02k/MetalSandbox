import MetalKit

extension MTLCommandBuffer {
    func debugGpuTime() -> Double {
        return (gpuEndTime - gpuStartTime)*1000
    }
}
