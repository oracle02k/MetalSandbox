import Metal

extension MTLCommandBuffer {
    func makeBlitCommandEncoderWithSafe() -> MTLBlitCommandEncoder {
        guard let encoder = makeBlitCommandEncoder() else {
            appFatalError("failed to make blit command encoder.")
        }
        return encoder
    }
    
    func makeComputeCommandEncoderWithSafe() -> MTLComputeCommandEncoder {
        guard let encoder = makeComputeCommandEncoder() else {
            appFatalError("failed to make compute command encoder.")
        }
        return encoder
    }
    
    func makeRenderCommandEncoderWithSafe(descriptor: MTLRenderPassDescriptor) -> MTLRenderCommandEncoder {
        guard let encoder = makeRenderCommandEncoder(descriptor: descriptor) else {
            appFatalError("failed to make render command encoder.")
        }
        return encoder
    }
}
