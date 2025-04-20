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

}
typealias ShaderFunctions = FunctionContainer<ShaderFunctionTable>

class RenderPass {
    let frameAllocator: GpuTransientAllocator
    let renderCommandRepository: RenderCommandRepository
    let renderStateResolver: RenderStateResolver
    let functions: ShaderFunctions
    let tileShaderParams = TileShaderParams()

    private(set) lazy var pixelFormats: AttachmentPixelFormats = uninitialized()

    init(
        frameAllocator: GpuTransientAllocator,
        renderCommandRepository: RenderCommandRepository,
        renderStateResolver: RenderStateResolver,
        functions: ShaderFunctions
    ) {
        self.frameAllocator = frameAllocator
        self.renderCommandRepository = renderCommandRepository
        self.renderStateResolver = renderStateResolver
        self.functions = functions
    }

    func build(pixelFormats: AttachmentPixelFormats) {
        self.pixelFormats = pixelFormats
    }

    func makeRenderCommandBuilder() -> RenderCommandBuilder {
        return RenderCommandBuilder(
            pixelFormats: pixelFormats,
            frameAllocator: frameAllocator,
            renderCommandRepository: renderCommandRepository,
            functions: functions,
            renderStateResolver: renderStateResolver,
            tileShaderParams: tileShaderParams
        )
    }

    func usingRenderCommandBuilder(_ body: (RenderCommandBuilder) -> Void) {
        body(makeRenderCommandBuilder())
    }

    func dispatch(to commandBuffer: MTLCommandBuffer, using descriptor: MTLRenderPassDescriptor) {
        /*
         for i in 0..<pixelFormats.colors.count {
         guard descriptor.colorAttachments[i].texture?.pixelFormat == pixelFormats.colors[i] else {
         appFatalError("invalid color attachment[\(i)] format.")
         }
         }

         guard descriptor.depthAttachment.texture?.pixelFormat == pixelFormats.depth else {
         appFatalError("invalid depth attachment format.")
         }

         guard descriptor.stencilAttachment.texture?.pixelFormat == pixelFormats.stencil else {
         appFatalError("invalid stencil attachment format.")
         }
         */

        if tileShaderParams.maxImageBlockSampleLength != 0 {
            descriptor.tileWidth = tileShaderParams.tileSize.width
            descriptor.tileHeight = tileShaderParams.tileSize.height
            descriptor.imageblockSampleLength = tileShaderParams.maxImageBlockSampleLength
        }

        let encoder = commandBuffer.makeRenderCommandEncoderWithSafe(descriptor: descriptor)
        let dispatcher = RenderCommandDispatcher(encoder: encoder)
        dispatcher.dispatch(renderCommandRepository.currentBuffer())
        encoder.endEncoding()
    }

    func clear() {
        renderCommandRepository.clear()
    }
}
