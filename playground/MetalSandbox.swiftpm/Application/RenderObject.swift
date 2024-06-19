import MetalKit

class RenderObject {
    struct Vertex {
        var position: float3
        var color: float4
        var texCoord: float2
    }

    private let pipelineStateFactory: MetalPipelineStateFactory
    private let primitivesFactory: Primitives.Factory
    private lazy var primitives: Primitives = uninitialized()
    private lazy var renderPipelineState: MTLRenderPipelineState = uninitialized()
    private lazy var depthStencilState: MTLDepthStencilState = uninitialized()
    private var depth = 0.0

    init (
        pipelineStateFactory: MetalPipelineStateFactory,
        primitivesFactory: Primitives.Factory
    ) {
        self.pipelineStateFactory = pipelineStateFactory
        self.primitivesFactory = primitivesFactory
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
    }

    func draw(_ encoder: MTLRenderCommandEncoder) {
        depth += 0.01
        if depth > 1 {
            depth = 0
        }

        primitives = {
            let vertexBufferDescriptor = VertexBufferDescriptor<Vertex>()
            vertexBufferDescriptor.content = [
                .init(position: float3(0, 1, 0), color: float4(1, 0, 0, 1), texCoord: float2(0, 0)),
                .init(position: float3(-1, -1, 0.5), color: float4(0, 1, 0, 1), texCoord: float2(0, 0)),
                .init(position: float3(1, -1, Float(depth)), color: float4(0, 0, 1, 1), texCoord: float2(0, 0))
            ]

            let descriptor = Primitives.Descriptor()
            descriptor.vertexBufferDescriptors = [vertexBufferDescriptor]
            descriptor.vertexCount = vertexBufferDescriptor.count
            descriptor.toporogy = .triangle

            return primitivesFactory.make(descriptor)
        }()

        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setDepthStencilState(depthStencilState)
        encoder.drawMesh(primitives)
    }
}
