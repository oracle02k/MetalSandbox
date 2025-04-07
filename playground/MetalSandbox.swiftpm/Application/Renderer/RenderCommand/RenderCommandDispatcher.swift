import Metal
import simd

class RenderCommandDispatcher{
    let encoder: MTLRenderCommandEncoder
    
    init(encoder: MTLRenderCommandEncoder){
        self.encoder = encoder
    }
    
    func dispatch(_ commandBuffer: [RenderCommand]){
        for command in commandBuffer {
            command.execute(self)
        }
    }   
}
