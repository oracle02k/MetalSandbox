import MetalKit

extension MTLCommandBuffer {
    func gpuTime() -> MilliSecond {
        return MilliSecond((gpuEndTime - gpuStartTime)*1000)
    }
}
