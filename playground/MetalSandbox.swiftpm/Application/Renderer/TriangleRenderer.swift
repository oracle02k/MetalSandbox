import MetalKit

class TriangleRenderer {
    struct Vertex {
        var position: float3
        var color: float4
        var texCoord: float2
    }

    private let pipelineStateFactory: MetalPipelineStateFactory
    private let meshFactory: Mesh.Factory
    private lazy var mesh: Mesh = uninitialized()
    private lazy var renderPipelineState: MTLRenderPipelineState = uninitialized()
    private lazy var depthStencilState: MTLDepthStencilState = uninitialized()
    
    init (
        pipelineStateFactory: MetalPipelineStateFactory,
        meshFactory: Mesh.Factory
    ) {
        self.pipelineStateFactory = pipelineStateFactory
        self.meshFactory = meshFactory
    }

    func build() {
        renderPipelineState = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "Basic Render Pipeline"
            descriptor.sampleCount = 1
            descriptor.vertexFunction = pipelineStateFactory.findFunction(by: .BasicVertexFunction)
            descriptor.fragmentFunction = pipelineStateFactory.findFunction(by: .BasicFragmentFunction)
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.depthAttachmentPixelFormat = .depth32Float
            return pipelineStateFactory.makeRenderPipelineState(descriptor)
        }()

        depthStencilState = {
            let descriptor = MTLDepthStencilDescriptor()
            descriptor.label = "Depth"
            descriptor.depthCompareFunction = .lessEqual
            descriptor.isDepthWriteEnabled = true
            return pipelineStateFactory.makeDepthStancilState(descriptor)
        }()
        
        mesh = {
           let vertexBufferDescriptor = VertexBufferDescriptor<Vertex>()
            vertexBufferDescriptor.content = [
                .init(position: float3(0, 1, 0.5), color: float4(1, 0, 0, 1), texCoord: float2(0, 0)),
                .init(position: float3(-1, -1, 0.5), color: float4(0, 1, 0, 1), texCoord: float2(0, 0)),
                .init(position: float3(1, -1, 0.5), color: float4(0, 0, 1, 1), texCoord: float2(0, 0))
            ]
            
            let descriptor = Mesh.Descriptor()
            descriptor.vertexBufferDescriptors = [vertexBufferDescriptor]
            descriptor.vertexCount = vertexBufferDescriptor.count
            descriptor.toporogy = .triangle
            
            return meshFactory.make(descriptor)
        }()
    }

    func draw(_ encoder: MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setDepthStencilState(depthStencilState)
        encoder.drawMesh(mesh)
    }
}
