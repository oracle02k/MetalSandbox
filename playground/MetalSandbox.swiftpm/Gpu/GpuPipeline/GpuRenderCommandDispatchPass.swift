import Metal

class GpuRenderCommandDispatchPass : GpuPass {
    var descriptor: MTLRenderPassDescriptor
    let dispatchParams: RenderCommandDispatchParams
    
    init(makeDescriptor: (MTLRenderPassDescriptor)->Void, dispatchParams: RenderCommandDispatchParams) {
        self.descriptor = MTLRenderPassDescriptor()
        self.dispatchParams = dispatchParams
        makeDescriptor(self.descriptor)
    }
    
    init( _ descriptor: MTLRenderPassDescriptor, dispatchParams: RenderCommandDispatchParams) {
        self.descriptor = descriptor
        self.dispatchParams = dispatchParams
    }
    
    func dispatch(_ commandBuffer: MTLCommandBuffer){
        RenderCommandDispatcher().dispatch(to: commandBuffer, descriptor: descriptor, params: dispatchParams)
    }
}
