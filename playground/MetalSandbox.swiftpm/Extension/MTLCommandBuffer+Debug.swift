import MetalKit

extension MTLCommandBuffer {
    func debugGpuTime() {
        let interval = gpuEndTime - gpuStartTime
        Debug.frameLog(String(format: "GpuTime: %.2fms", interval*1000))
    }
}
