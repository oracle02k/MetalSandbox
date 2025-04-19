import Metal

protocol RenderCommand {
    func execute(_ dispatcher: RenderCommandDispatcher)
}

struct SetRenderPipelineState: RenderCommand {
    let renderPipelineState: MTLRenderPipelineState

    func execute(_ dispatcher: RenderCommandDispatcher) {
        dispatcher.encoder.setRenderPipelineState(renderPipelineState)
    }
}

struct SetDepthStencilState: RenderCommand {
    let depthStencilState: MTLDepthStencilState

    func execute(_ dispatcher: RenderCommandDispatcher) {
        dispatcher.encoder.setDepthStencilState(depthStencilState)
    }
}

struct SetVertexBuffer: RenderCommand {
    let buffer: MTLBuffer
    let offset: Int
    let index: Int

    func execute(_ dispatcher: RenderCommandDispatcher) {
        dispatcher.encoder.setVertexBuffer(buffer, offset: offset, index: index)
    }
}

struct SetFragmentBuffer: RenderCommand {
    let buffer: MTLBuffer
    let offset: Int
    let index: Int

    func execute(_ dispatcher: RenderCommandDispatcher) {
        dispatcher.encoder.setFragmentBuffer(buffer, offset: offset, index: index)
    }
}

struct SetVertexBufferOffset: RenderCommand {
    let offset: Int
    let index: Int
    
    func execute(_ dispatcher: RenderCommandDispatcher) {
        dispatcher.encoder.setVertexBufferOffset(offset, index: index)
    }
}

struct SetFragmentBufferOffset: RenderCommand {
    let offset: Int
    let index: Int
    
    func execute(_ dispatcher: RenderCommandDispatcher) {
        dispatcher.encoder.setFragmentBufferOffset(offset, index: index)
    }
}


struct DrawPrimitives: RenderCommand {
    let type: MTLPrimitiveType
    let vertexStart: Int
    let vertexCount: Int

    func execute(_ dispatcher: RenderCommandDispatcher) {
        dispatcher.encoder.drawPrimitives(type: type, vertexStart: vertexStart, vertexCount: vertexCount)
    }
}

struct DispatchThreadsPerTile: RenderCommand {
    let threadsPerTile: MTLSize

    func execute(_ dispatcher: RenderCommandDispatcher) {
        dispatcher.encoder.dispatchThreadsPerTile(threadsPerTile)
    }
}

struct SetFragmentTexture: RenderCommand {
    let texture: MTLTexture
    let index: Int

    func execute(_ dispatcher: RenderCommandDispatcher) {
        dispatcher.encoder.setFragmentTexture(texture, index: index)
    }
}

struct PushDebugGroup: RenderCommand {
    let label: String

    func execute(_ dispatcher: RenderCommandDispatcher) {
        dispatcher.encoder.pushDebugGroup(label)
    }
}

struct PopDebugGroup: RenderCommand {
    func execute(_ dispatcher: RenderCommandDispatcher) {
        dispatcher.encoder.popDebugGroup()
    }
}

struct SetCullMode: RenderCommand {
    let mode: MTLCullMode

    func execute(_ dispatcher: RenderCommandDispatcher) {
        dispatcher.encoder.setCullMode(mode)
    }
}
