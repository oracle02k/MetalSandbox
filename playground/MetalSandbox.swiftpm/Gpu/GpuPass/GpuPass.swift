import Metal

protocol GpuPass {
    func dispatch(_ commandBuffer: MTLCommandBuffer)
}
