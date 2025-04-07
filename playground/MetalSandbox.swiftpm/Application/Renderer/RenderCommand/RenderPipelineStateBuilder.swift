import Metal

class RenderPipelineStateBuilder{
    let gpu: GpuContext
    var cache = [Int: MTLRenderPipelineState]()
    
    init(gpu: GpuContext){
        self.gpu = gpu
    }
    
    func build(_ descriptor: MTLRenderPipelineDescriptor) -> MTLRenderPipelineState {
        guard let pso = cache[descriptor.hash] else{
            let pso = gpu.makeRenderPipelineState(descriptor)
            cache[descriptor.hash] = pso
            return pso
        }
        
        return pso
    }
}
