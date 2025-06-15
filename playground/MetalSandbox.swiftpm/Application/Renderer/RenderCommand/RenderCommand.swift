import Metal

enum ShaderFunctionTable: String, FunctionTableProvider {
    static let FileName = ""
    case InvalidVS = "invalid::vs"
    case InvalidFS = "invalid::fs"
    case VertexShader = "triangle::vertex_shader"
    case FragmentShader = "triangle::fragment_shader"
    case PassthroughtTextureVS = "passthrought_texture::vs"
    case PassthroughtTextureFS = "passthrought_texture::fs"
    case TileForwardVS = "tile::forward_vertex"
    case TileOpaqueFS = "tile::process_opaque_fragment"
    case TileInitTransparentFragmentStore = "tile::init_transparent_fragment_store"
    case TileProcessTransparentFS = "tile::process_transparent_fragment"
    case TileQuadPassVS = "tile::quad_pass_vertex"
    case TileBlendFS = "tile::blend_fragments"
    case IndirectVSWithInstance = "indirect::vertex_shader_with_instance"
    case IndirectVS = "indirect::vertex_shader"
    case IndirectFS = "indirect::fragment_shader"
}
typealias ShaderFunctions = FunctionContainer<ShaderFunctionTable>

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
    let instanceCount: Int
    let baseInstance: Int

    func execute(_ dispatcher: RenderCommandDispatcher) {
        dispatcher.encoder.drawPrimitives(type: type, vertexStart: vertexStart, vertexCount: vertexCount, instanceCount: instanceCount, baseInstance: baseInstance)
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

struct UseResource: RenderCommand {
    let resource: MTLResource
    let usage: MTLResourceUsage
    let stages: MTLRenderStages
    
    func execute(_ dispatcher: RenderCommandDispatcher) {
        dispatcher.encoder.useResource(resource, usage: usage, stages: stages)
    }
}

struct ExecuteCommandsInBuffer: RenderCommand {
    let indirectCommandBuffer: any MTLIndirectCommandBuffer
    let range: Range<Int>
    
    func execute(_ dispatcher: RenderCommandDispatcher) {
        dispatcher.encoder.executeCommandsInBuffer(indirectCommandBuffer, range: range)
    }
}
