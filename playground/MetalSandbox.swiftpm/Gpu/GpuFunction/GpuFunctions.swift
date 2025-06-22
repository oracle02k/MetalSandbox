enum GpuFunctionTable: String, GpuFunctionTableProvider {
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
typealias GpuFunctions = GpuFunctionContainer<GpuFunctionTable>
