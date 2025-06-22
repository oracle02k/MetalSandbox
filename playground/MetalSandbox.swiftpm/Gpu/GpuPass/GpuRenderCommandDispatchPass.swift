import Metal

class GpuRenderCommandDispatchPass: GpuPass {
    var descriptor: MTLRenderPassDescriptor
    let dispatchParams: GpuRenderCommandDispatchParams

    init(makeDescriptor: (MTLRenderPassDescriptor) -> Void, dispatch dispatchParams: GpuRenderCommandDispatchParams) {
        self.descriptor = MTLRenderPassDescriptor()
        self.dispatchParams = dispatchParams
        makeDescriptor(self.descriptor)
    }

    init( _ descriptor: MTLRenderPassDescriptor, dispatch dispatchParams: GpuRenderCommandDispatchParams) {
        self.descriptor = descriptor
        self.dispatchParams = dispatchParams
    }

    func dispatch(_ commandBuffer: MTLCommandBuffer) {
        GpuRenderCommandDispatcher().dispatch(to: commandBuffer, descriptor: descriptor, params: dispatchParams)
    }
}
