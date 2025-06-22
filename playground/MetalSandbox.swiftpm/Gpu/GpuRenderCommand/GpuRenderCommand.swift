import Metal

protocol GpuRenderCommand {
    func execute(_ dispatcher: GpuRenderCommandDispatcher)
}

struct SetRenderPipelineState: GpuRenderCommand {
    let renderPipelineState: MTLRenderPipelineState
    
    func execute(_ dispatcher: GpuRenderCommandDispatcher) {
        dispatcher.encoder.setRenderPipelineState(renderPipelineState)
    }
}

struct SetDepthStencilState: GpuRenderCommand {
    let depthStencilState: MTLDepthStencilState
    
    func execute(_ dispatcher: GpuRenderCommandDispatcher) {
        dispatcher.encoder.setDepthStencilState(depthStencilState)
    }
}

struct SetVertexBuffer: GpuRenderCommand {
    let buffer: MTLBuffer
    let offset: Int
    let index: Int
    
    func execute(_ dispatcher: GpuRenderCommandDispatcher) {
        dispatcher.encoder.setVertexBuffer(buffer, offset: offset, index: index)
    }
}

struct SetFragmentBuffer: GpuRenderCommand {
    let buffer: MTLBuffer
    let offset: Int
    let index: Int
    
    func execute(_ dispatcher: GpuRenderCommandDispatcher) {
        dispatcher.encoder.setFragmentBuffer(buffer, offset: offset, index: index)
    }
}

struct SetVertexBufferOffset: GpuRenderCommand {
    let offset: Int
    let index: Int
    
    func execute(_ dispatcher: GpuRenderCommandDispatcher) {
        dispatcher.encoder.setVertexBufferOffset(offset, index: index)
    }
}

struct SetFragmentBufferOffset: GpuRenderCommand {
    let offset: Int
    let index: Int
    
    func execute(_ dispatcher: GpuRenderCommandDispatcher) {
        dispatcher.encoder.setFragmentBufferOffset(offset, index: index)
    }
}

struct DrawPrimitives: GpuRenderCommand {
    let type: MTLPrimitiveType
    let vertexStart: Int
    let vertexCount: Int
    let instanceCount: Int
    let baseInstance: Int
    
    func execute(_ dispatcher: GpuRenderCommandDispatcher) {
        dispatcher.encoder.drawPrimitives(type: type, vertexStart: vertexStart, vertexCount: vertexCount, instanceCount: instanceCount, baseInstance: baseInstance)
    }
}

struct DispatchThreadsPerTile: GpuRenderCommand {
    let threadsPerTile: MTLSize
    
    func execute(_ dispatcher: GpuRenderCommandDispatcher) {
        dispatcher.encoder.dispatchThreadsPerTile(threadsPerTile)
    }
}

struct SetFragmentTexture: GpuRenderCommand {
    let texture: MTLTexture
    let index: Int
    
    func execute(_ dispatcher: GpuRenderCommandDispatcher) {
        dispatcher.encoder.setFragmentTexture(texture, index: index)
    }
}

struct PushDebugGroup: GpuRenderCommand {
    let label: String
    
    func execute(_ dispatcher: GpuRenderCommandDispatcher) {
        dispatcher.encoder.pushDebugGroup(label)
    }
}

struct PopDebugGroup: GpuRenderCommand {
    func execute(_ dispatcher: GpuRenderCommandDispatcher) {
        dispatcher.encoder.popDebugGroup()
    }
}

struct SetCullMode: GpuRenderCommand {
    let mode: MTLCullMode
    
    func execute(_ dispatcher: GpuRenderCommandDispatcher) {
        dispatcher.encoder.setCullMode(mode)
    }
}

struct UseResource: GpuRenderCommand {
    let resource: MTLResource
    let usage: MTLResourceUsage
    let stages: MTLRenderStages
    
    func execute(_ dispatcher: GpuRenderCommandDispatcher) {
        dispatcher.encoder.useResource(resource, usage: usage, stages: stages)
    }
}

struct ExecuteCommandsInBuffer: GpuRenderCommand {
    let indirectCommandBuffer: any MTLIndirectCommandBuffer
    let range: Range<Int>
    
    func execute(_ dispatcher: GpuRenderCommandDispatcher) {
        dispatcher.encoder.executeCommandsInBuffer(indirectCommandBuffer, range: range)
    }
}
