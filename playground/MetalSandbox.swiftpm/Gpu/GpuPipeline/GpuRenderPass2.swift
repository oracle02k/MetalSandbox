import Metal

class GpuRenderPass2 : GpuPass {
    var descriptor = MTLRenderPassDescriptor()
    let renderPass: RenderPass
    
    init( 
        makeDescriptor: (MTLRenderPassDescriptor)->Void,
        renderPass: RenderPass
    ){
        makeDescriptor(self.descriptor)
        self.renderPass = renderPass
    }
    
    init( 
        _ descriptor: MTLRenderPassDescriptor,
        renderPass: RenderPass
    ){
        self.descriptor = descriptor
        self.renderPass = renderPass
    }
    
    func dispatch(_ commandBuffer: MTLCommandBuffer){
        renderPass.dispatch(to: commandBuffer, using: descriptor)
    }
}
