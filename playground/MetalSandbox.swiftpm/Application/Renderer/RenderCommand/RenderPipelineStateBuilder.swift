import Metal

class RenderStateResolver{
    let gpu: GpuContext
    var pipelineStates = [Int: MTLRenderPipelineState]()
    var depthStencilStates = [Int: MTLDepthStencilState]()
    var tilePipelineStates = [Int: MTLRenderPipelineState]()
    
    init(gpu: GpuContext){
        self.gpu = gpu
    }
    
    func resolvePipelineState(_ descriptor: MTLRenderPipelineDescriptor) -> MTLRenderPipelineState {
        guard let state = pipelineStates[descriptor.hash] else{
            let state = gpu.makeRenderPipelineState(descriptor)
            pipelineStates[descriptor.hash] = state
            return state
        }
        
        return state
    }
    
    func resolveDepthStencilState(_ descriptor: MTLDepthStencilDescriptor) -> MTLDepthStencilState {
        guard let state = depthStencilStates[descriptor.hash] else{
            let state = gpu.makeDepthStancilState(descriptor)
            depthStencilStates[descriptor.hash] = state
            return state
        }
        
        return state
    }
    
    func resolveTilePipelineState(_ descriptor: MTLTileRenderPipelineDescriptor) -> MTLRenderPipelineState {
        guard let state = tilePipelineStates[descriptor.hash] else{
            let state = try! gpu.device.makeRenderPipelineState(tileDescriptor: descriptor, options: [], reflection: nil)
            tilePipelineStates[descriptor.hash] = state
            return state
        }
        
        return state
    }
}
