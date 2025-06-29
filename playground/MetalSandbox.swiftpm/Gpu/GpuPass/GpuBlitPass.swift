import Metal

class GpuBlitPass: GpuPass {
    var descriptor = MTLBlitPassDescriptor()
    let performEncoding: (MTLBlitCommandEncoder) -> Void
    
    init(
        makeDescriptor: (MTLBlitPassDescriptor) -> Void,
        performEncoding: @escaping (MTLBlitCommandEncoder) -> Void
    ) {
        makeDescriptor(self.descriptor)
        self.performEncoding = performEncoding
    }
    
    init(
        _ descriptor: MTLBlitPassDescriptor,
        performEncoding: @escaping (MTLBlitCommandEncoder) -> Void
    ) {
        self.descriptor = descriptor
        self.performEncoding = performEncoding
    }
    
    func dispatch(_ commandBuffer: MTLCommandBuffer) {
        let encoder = commandBuffer.makeBlitCommandEncoderWithSafe(descriptor: descriptor)
        performEncoding(encoder)
        encoder.endEncoding()
    }
}
