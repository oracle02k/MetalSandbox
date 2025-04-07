import Metal

protocol RenderCommand {
    func execute(_ dispatcher: RenderCommandDispatcher)
}

struct SetRenderPipelineState : RenderCommand {
    let renderPipelineState: MTLRenderPipelineState
    
    func execute(_ dispatcher: RenderCommandDispatcher){
        dispatcher.encoder.setRenderPipelineState(renderPipelineState)
    }
}

struct SetVertexBuffer : RenderCommand {
    let buffer: MTLBuffer
    let offset: Int
    let index: Int
    
    func execute(_ dispatcher: RenderCommandDispatcher){
        dispatcher.encoder.setVertexBuffer(buffer, offset: offset, index: index)
    }
}

struct DrawPrimitives  : RenderCommand {
    let type: MTLPrimitiveType
    let vertexStart: Int
    let vertexCount: Int
    
    func execute(_ dispatcher: RenderCommandDispatcher){
        dispatcher.encoder.drawPrimitives(type: type, vertexStart: vertexStart, vertexCount: vertexCount)
    }
}

struct SetFragmentTexture: RenderCommand {
    let texture: MTLTexture
    let index: Int
    
    func execute(_ dispatcher: RenderCommandDispatcher) {
        dispatcher.encoder.setFragmentTexture(texture, index: index)
    }
}
