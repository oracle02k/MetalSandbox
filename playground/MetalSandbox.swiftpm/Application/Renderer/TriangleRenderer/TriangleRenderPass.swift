import MetalKit

class TriangleRenderPass {
    typealias Functions = FunctionContainer<FunctionNames>

    enum RenderTargetIndices: Int {
        case Color           = 0
    }

    enum FunctionNames: String, CaseIterable {
        case VertexShader = "triangle::vertex_shader"
        case FragmentShader = "triangle::fragment_shader"
    }

    struct Vertex {
        var position: simd_float3
        var color: simd_float4
    }

    private let gpu: GpuContext
    private var screenViewport: Viewport
    private let functions: Functions
    private lazy var renderPipelineState: MTLRenderPipelineState = uninitialized()
    private lazy var depthStencilState: MTLDepthStencilState = uninitialized()
    private lazy var renderPassDescriptor: MTLRenderPassDescriptor = uninitialized()
    // private lazy var counterSampleBuffer: MTLCounterSampleBuffer? = uninitialized()
    private lazy var vertices: TypedBuffer<Vertex> = uninitialized()

    init (with gpu: GpuContext, functions: Functions) {
        self.gpu = gpu
        self.functions = functions
        self.screenViewport = .init(leftTop: .init(0, 0), rightBottom: .init(320, 320))
    }

    func build(with gpuCountreSampleGroup: GpuCounterSampleGroup? = nil) {
        functions.build(fileName: "triangle.txt")

        renderPipelineState = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "Simple 2D Render Pipeline"
            descriptor.sampleCount = 1
            descriptor.vertexFunction = functions.find(by: .VertexShader)
            descriptor.fragmentFunction = functions.find(by: .FragmentShader)
            descriptor.colorAttachments[RenderTargetIndices.Color.rawValue].pixelFormat = .bgra8Unorm
            descriptor.depthAttachmentPixelFormat = .depth32Float
            return gpu.makeRenderPipelineState(descriptor)
        }()

        depthStencilState = {
            let descriptor = MTLDepthStencilDescriptor()
            descriptor.label = "Depth"
            descriptor.depthCompareFunction = .lessEqual
            descriptor.isDepthWriteEnabled = true
            return gpu.makeDepthStancilState(descriptor)
        }()

        renderPassDescriptor = MTLRenderPassDescriptor()
        _ = gpuCountreSampleGroup?.addSampleRenderInterval(of: renderPassDescriptor, label: "triangle render pass")

        vertices = gpu.makeTypedBuffer(elementCount: 3, options: []) as TypedBuffer<Vertex>
        vertices[0] = .init(position: .init(160, 0, 0.0), color: .init(1, 0, 0, 1))
        vertices[1] = .init(position: .init(0, 320, 0.0), color: .init(0, 1, 0, 1))
        vertices[2] = .init(position: .init(320, 320, 0.0), color: .init(0, 0, 1, 1))
    }

    func draw(toColor: MTLRenderPassColorAttachmentDescriptor, using commandBuffer: MTLCommandBuffer) {
        let encoder = {
            renderPassDescriptor.colorAttachments[RenderTargetIndices.Color.rawValue] = toColor
            return commandBuffer.makeRenderCommandEncoderWithSafe(descriptor: renderPassDescriptor)
        }()

        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setDepthStencilState(depthStencilState)
        withUnsafeMutablePointer(to: &screenViewport) {
            encoder.setVertexBytes($0, length: MemoryLayout<Viewport>.stride, index: VertexInputIndex.Viewport.rawValue)
        }
        encoder.setVertexBuffer(vertices.rawBuffer, offset: 0, index: VertexInputIndex.Vertices1.rawValue)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }
}
