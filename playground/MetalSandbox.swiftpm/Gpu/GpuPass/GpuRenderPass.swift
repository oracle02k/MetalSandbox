import Metal

class GpuRenderPass : GpuPass {
    var descriptor = MTLRenderPassDescriptor()
    let performEncoding: (MTLRenderCommandEncoder) -> Void
    
    init( 
        makeDescriptor: (MTLRenderPassDescriptor)->Void,
        performEncoding: @escaping (MTLRenderCommandEncoder)->Void
    ){
        makeDescriptor(self.descriptor)
        self.performEncoding = performEncoding
    }
    
    init( 
        _ descriptor: MTLRenderPassDescriptor,
        performEncoding: @escaping (MTLRenderCommandEncoder)->Void
    ){
        self.descriptor = descriptor
        self.performEncoding = performEncoding
    }
    
    func dispatch(_ commandBuffer: MTLCommandBuffer){
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        performEncoding(encoder)
        encoder.endEncoding()
    }
}
