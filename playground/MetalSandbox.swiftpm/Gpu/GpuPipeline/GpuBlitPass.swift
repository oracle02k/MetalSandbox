import Metal

class GpuBlitPass : GpuPass {
    let performEncoding: (MTLBlitCommandEncoder) -> Void
    
    init( performEncoding: @escaping (MTLBlitCommandEncoder)->Void ){
        self.performEncoding = performEncoding
    }
    
    func dispatch(_ commandBuffer: MTLCommandBuffer){
        let encoder = commandBuffer.makeBlitCommandEncoderWithSafe()
        performEncoding(encoder)
        encoder.endEncoding()
    }
}
