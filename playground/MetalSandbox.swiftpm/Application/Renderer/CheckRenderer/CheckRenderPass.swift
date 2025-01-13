//
//  CheckRenderPass.swift
//  MetalSandbox
//
//  Created by Akira Nakano on 2024/12/29.
//
import MetalKit

struct Uniforms {
    let aspectRatio: Float
}

struct Const {
    static let maxBuffersInFlight: Int = 3
    // 処理するテクスチャのサイズ
    static let textureWidth = 80
    static let textureHeight = 70
    static let textureName = "tex80x70"
    // Uniformバッファは256バイトの倍数にする（今回のサンプルでは無用。。。）
    static let alignedUniformsSize =
        (MemoryLayout<Uniforms>.size & ~0xFF) + 0x100
    // Metal 画像頂点座標(x,y), uv座標(u,v)
    static let kImagePlaneVertexData: [Float] = [
        -1.0, -1.0, 0.0, 1.0,
        1.0, -1.0, 1.0, 1.0,
        -1.0, 1.0, 0.0, 0.0,
        1.0, 1.0, 1.0, 0.0,
    ]
}

class CheckRenderPass {
    typealias Functions = FunctionContainer<FunctionNames>

    enum FunctionNames: String, CaseIterable {
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
    private let functions: Functions
    private let indexedMeshFactory: IndexedMesh.Factory
    private lazy var indexedMesh: IndexedMesh = uninitialized()
    private lazy var renderPipelineState: MTLRenderPipelineState = uninitialized()
    private lazy var renderPassDescriptor: MTLRenderPassDescriptor = uninitialized()
    private lazy var counterSampleBuffer: MTLCounterSampleBuffer? = uninitialized()
    private lazy var texture: MTLTexture = uninitialized()

    init(with gpu: GpuContext, indexedMeshFactory: IndexedMesh.Factory, functions: Functions) {
        self.gpu = gpu
        self.indexedMeshFactory = indexedMeshFactory
        self.functions = functions
    }
    
    func build() {
        functions.build(fileName: "raster_order_group.txt")
        
        renderPipelineState = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "RenderPipeline"
            descriptor.vertexFunction = functions.find(by: .TexcoordVertexShader)
            descriptor.fragmentFunction = functions.find(by: .Rog0Fragment)
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
            texture = try loader.newTexture(name: "checkc32", scaleFactor: 1.0, bundle: nil, options: nil)
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

        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentTexture(write, index: 1)
        encoder.drawIndexedMesh(indexedMesh)
        encoder.endEncoding()
    }

    func debugFrameStatus() -> String {
        return gpu.debugCountreSampleLog(label: "rog render pass", from: counterSampleBuffer)
    }
}
