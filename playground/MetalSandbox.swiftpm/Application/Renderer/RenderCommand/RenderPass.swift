import Metal

enum ShaderFunctionTable: String, FunctionTableProvider {
    static let FileName = ""
    case InvalidVS = "invalid::vs"
    case InvalidFS = "invalid::fs"
    case VertexShader = "triangle::vertex_shader"
    case FragmentShader = "triangle::fragment_shader"
    case PassthroughtTextureVS = "passthrought_texture::vs"
    case PassthroughtTextureFS = "passthrought_texture::fs"
    case TileFowardVS = "tile::forward_vertex"
    case TileOpaqueFS = "tile::process_opaque_fragment"
}
typealias ShaderFunctions = FunctionContainer<ShaderFunctionTable>

class RenderPass {
    let frameAllocator: GpuFrameAllocator
    let renderCommandRepository: RenderCommandRepository
    let renderPipelineStateBuilder: RenderPipelineStateBuilder
    let functions: ShaderFunctions
    
    init(
        frameAllocator: GpuFrameAllocator,
        renderCommandRepository: RenderCommandRepository,
        renderPipelineStateBuilder: RenderPipelineStateBuilder,
        functions: ShaderFunctions
    ){
        self.frameAllocator = frameAllocator
        self.renderCommandRepository = renderCommandRepository
        self.renderPipelineStateBuilder = renderPipelineStateBuilder
        self.functions = functions
    }
    
    func makeRenderCommandBuilder() -> RenderCommandBuilder {
        return RenderCommandBuilder(
            frameAllocator:frameAllocator, 
            renderCommandRepository: renderCommandRepository,
            functions: functions,
            renderPipelineStateBuilder: renderPipelineStateBuilder
        )
    }
    
    func usingRenderCommandBuilder(_ body: (RenderCommandBuilder) -> Void){
        body(makeRenderCommandBuilder())
    }
    
    func dispatch(to commandBuffer: MTLCommandBuffer, using descriptor: MTLRenderPassDescriptor) {
        let encoder = commandBuffer.makeRenderCommandEncoderWithSafe(descriptor: descriptor)
        let dispatcher = RenderCommandDispatcher(encoder: encoder)
        dispatcher.dispatch(renderCommandRepository.currentBuffer())
        encoder.endEncoding()
    }
    
    func clear(){
        renderCommandRepository.clear()
    }
}
