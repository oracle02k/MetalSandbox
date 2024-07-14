import MetalKit

class TriangleRenderer {
    struct Vertex {
        var position: simd_float3
        var color: simd_float4
        var texCoord: simd_float2
    }

    private var screenViewport: Viewport
    private let pipelineStateFactory: MetalPipelineStateFactory
    private let meshFactory: Mesh.Factory
    private let resourceFactory: MetalResourceFactory
    private lazy var mesh: Mesh = uninitialized()
    private lazy var renderPipelineState: MTLRenderPipelineState = uninitialized()
    private lazy var depthStencilState: MTLDepthStencilState = uninitialized()
    private lazy var vertices: TypedBuffer<Vertex> = uninitialized()

    init (
        pipelineStateFactory: MetalPipelineStateFactory,
        meshFactory: Mesh.Factory,
        resourceFactory: MetalResourceFactory
    ) {
        self.pipelineStateFactory = pipelineStateFactory
        self.meshFactory = meshFactory
        self.resourceFactory = resourceFactory
        screenViewport = .init(leftTop: .init(0, 0), rightBottom: .init(320, 320))
    }

    func build() {
        renderPipelineState = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "Simple 2D Render Pipeline"
            descriptor.sampleCount = 1
            descriptor.vertexFunction = pipelineStateFactory.findFunction(by: .Simple2dVertexFunction)
            descriptor.fragmentFunction = pipelineStateFactory.findFunction(by: .Simple2dFragmentFunction)
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
                .init(position: .init(160, 0, 0.5), color: .init(1, 0, 0, 1), texCoord: .init(0, 0)),
                .init(position: .init(0, 320, 0.5), color: .init(0, 1, 0, 1), texCoord: .init(0, 0)),
                .init(position: .init(320, 320, 0.5), color: .init(0, 0, 1, 1), texCoord: .init(0, 0))
            ]
 
            
            let descriptor = Mesh.Descriptor()
            descriptor.vertexBufferDescriptors = [vertexBufferDescriptor]
            descriptor.vertexCount = vertexBufferDescriptor.count
            descriptor.toporogy = .triangle

            return meshFactory.make(descriptor)
        }()
        
        vertices = resourceFactory.makeTypedBuffer(elementCount:3, options: []) as TypedBuffer<Vertex>
        vertices[0] = .init(position: .init(160, 0, 0.5), color: .init(1, 0, 0, 1), texCoord: .init(0, 0))
        vertices[1] = .init(position: .init(0, 320, 0.5), color: .init(0, 1, 0, 1), texCoord: .init(0, 0))
        vertices[2] = .init(position: .init(320, 320, 0.5), color: .init(0, 0, 1, 1), texCoord: .init(0, 0))
    }

    func draw(_ encoder: MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setDepthStencilState(depthStencilState)
        withUnsafeMutablePointer(to: &screenViewport) {
            encoder.setVertexBytes($0, length: MemoryLayout<Viewport>.stride, index: VertexInputIndex.Viewport.rawValue)
        }
        encoder.setVertexBuffer(vertices.rawBuffer, offset: 0, index: VertexInputIndex.Vertices1.rawValue)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        //encoder.drawMesh(mesh)
    }
}
