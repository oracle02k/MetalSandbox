import MetalKit

class RasterOrderGroupRenderPass {
    typealias Functions = FunctionContainer<FunctionTable>

    enum FunctionTable: String, FunctionTableProvider {
        static let FileName = "rastor_order_group.txt"
        case TexcoordVertexShader = "raster_order_group::texcoord_vertex_shader"
        case Rog0Fragment = "raster_order_group::rog_0_fragment"
        case Rog1Fragment = "raster_order_group::rog_1_fragment"
    }

    struct Vertex {
        var position: simd_float3
        var color: simd_float4
        var texCoord: simd_float2
    }

    private let gpu: GpuContext
    private let indexedMeshFactory: IndexedMesh.Factory
    private let functions: Functions
    private lazy var indexedMesh: IndexedMesh = uninitialized()
    private lazy var indexedMesh2: IndexedMesh = uninitialized()
    private lazy var indexedMesh3: IndexedMesh = uninitialized()
    private lazy var rasterOrderGroup0: MTLRenderPipelineState = uninitialized()
    private lazy var rasterOrderGroup1: MTLRenderPipelineState = uninitialized()
    private lazy var renderPassDescriptor: MTLRenderPassDescriptor = uninitialized()
    private lazy var counterSampleBuffer: MTLCounterSampleBuffer? = uninitialized()
    private lazy var texture: MTLTexture = uninitialized()

    init(with gpu: GpuContext, indexedMeshFactory: IndexedMesh.Factory, functions: Functions) {
        self.gpu = gpu
        self.indexedMeshFactory = indexedMeshFactory
        self.functions = functions
    }

    func build() {
        functions.build()
        rasterOrderGroup0 = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "Raster Order Group 0 Pipeline"
            descriptor.sampleCount = 1
            descriptor.vertexFunction = functions.find(by: .TexcoordVertexShader)
            descriptor.fragmentFunction = functions.find(by: .Rog0Fragment)
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            return gpu.makeRenderPipelineState(descriptor)
        }()

        rasterOrderGroup1 = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "Raster Order Group 1 Pipeline"
            descriptor.sampleCount = 1
            descriptor.vertexFunction = functions.find(by: .TexcoordVertexShader)
            descriptor.fragmentFunction = functions.find(by: .Rog1Fragment)
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            return gpu.makeRenderPipelineState(descriptor)
        }()

        renderPassDescriptor = MTLRenderPassDescriptor()
        counterSampleBuffer = gpu.attachCounterSample(
            to: renderPassDescriptor,
            index: 0
        )

        do {
            let loader = MTKTextureLoader(device: gpu.device)
            texture = try loader.newTexture(name: "photo", scaleFactor: 1.0, bundle: nil, options: nil)
        } catch {
            appFatalError("faild to make texture.", error: error)
        }

        let vertices: [Vertex] = [
            .init(position: .init(-1, 1, 0), color: .init(0, 0, 0, 1), texCoord: .init(0, 0)),
            .init(position: .init(-1, -1, 0), color: .init(0, 0, 0, 1), texCoord: .init(0, 1)),
            .init(position: .init(1, -1, 0), color: .init(0, 0, 0, 1), texCoord: .init(1, 1)),
            .init(position: .init(1, 1, 0), color: .init(0, 0, 0, 1), texCoord: .init(1, 0))
        ]
        indexedMesh = makeQuad(vertices: vertices)

        let vertices2: [Vertex] = [
            .init(position: .init(-1 + 1, 1, 0), color: .init(0, 0, 0, 1), texCoord: .init(0, 0)),
            .init(position: .init(-1 + 1, -1, 0), color: .init(0, 0, 0, 1), texCoord: .init(0, 1)),
            .init(position: .init(1 + 1, -1, 0), color: .init(0, 0, 0, 1), texCoord: .init(1, 1)),
            .init(position: .init(1 + 1, 1, 0), color: .init(0, 0, 0, 1), texCoord: .init(1, 0))
        ]
        indexedMesh2 = makeQuad(vertices: vertices2)

        let vertices3: [Vertex] = [
            .init(position: .init(-1, 1-1, 0), color: .init(0, 0, 0, 1), texCoord: .init(0, 0)),
            .init(position: .init(-1, -1-1, 0), color: .init(0, 0, 0, 1), texCoord: .init(0, 1)),
            .init(position: .init(1, -1-1, 0), color: .init(0, 0, 0, 1), texCoord: .init(1, 1)),
            .init(position: .init(1, 1-1, 0), color: .init(0, 0, 0, 1), texCoord: .init(1, 0))
        ]
        indexedMesh3 = makeQuad(vertices: vertices3)
    }

    func makeQuad(vertices: [Vertex]) -> IndexedMesh {
        let vertextBufferDescriptor = VertexBufferDescriptor<Vertex>()
        vertextBufferDescriptor.content = vertices

        let indexBufferDescriptor = IndexBufferU16Descriptor()
        indexBufferDescriptor.content = [0, 1, 2, 2, 3, 0]

        let descriptor = IndexedMesh.Descriptor()
        descriptor.vertexBufferDescriptors = [vertextBufferDescriptor]
        descriptor.indexBufferDescriptor = indexBufferDescriptor
        descriptor.toporogy = .triangle

        return indexedMeshFactory.make(descriptor)
    }

    func draw(
        toColor: MTLRenderPassColorAttachmentDescriptor,
        write: MTLTexture,
        using commandBuffer: MTLCommandBuffer
    ) {
        let encoder = {
            renderPassDescriptor.colorAttachments[0] = toColor
            return commandBuffer.makeRenderCommandEncoderWithSafe(descriptor: renderPassDescriptor)
        }()

        encoder.setRenderPipelineState(rasterOrderGroup0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentTexture(write, index: 1)
        encoder.drawIndexedMesh(indexedMesh)
        encoder.drawIndexedMesh(indexedMesh2)
        encoder.setRenderPipelineState(rasterOrderGroup1)
        encoder.drawIndexedMesh(indexedMesh3)
        encoder.endEncoding()
    }

    func debugFrameStatus() -> String {
        return gpu.debugCountreSampleLog(label: "rog render pass", from: counterSampleBuffer)
    }
}
