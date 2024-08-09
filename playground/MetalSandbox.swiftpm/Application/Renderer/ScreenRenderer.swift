import MetalKit

class ScreenRenderer {
    struct Vertex {
        var position: simd_float3
        var color: simd_float4
        var texCoord: simd_float2
    }
    
    private let gpu: GpuContext
    private let indexedMeshFactory: IndexedMesh.Factory
    private lazy var indexedMesh: IndexedMesh = uninitialized()
    private lazy var renderPipelineState: MTLRenderPipelineState = uninitialized()
    private lazy var renderPassDescriptor: MTLRenderPassDescriptor = uninitialized()
    private lazy var counterSampleBuffer: MTLCounterSampleBuffer? = uninitialized()

    init(gpu: GpuContext, indexedMeshFactory: IndexedMesh.Factory) {
        self.gpu = gpu
        self.indexedMeshFactory = indexedMeshFactory
    }

    func build() {
        renderPipelineState = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "Screen Render Pipeline"
            descriptor.sampleCount = 1
            descriptor.vertexFunction = gpu.findFunction(by: .TexcoordVertexFuction)
            descriptor.fragmentFunction = gpu.findFunction(by: .TexcoordFragmentFunction)
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            return gpu.makeRenderPipelineState(descriptor)
        }()
        
        renderPassDescriptor = MTLRenderPassDescriptor()
        counterSampleBuffer = gpu.attachCounterSample(
            to: renderPassDescriptor, 
            index: 0
        )

        indexedMesh = {
            let vertextBufferDescriptor = VertexBufferDescriptor<Vertex>()
            vertextBufferDescriptor.content = [
                .init(position: .init(-1, 1, 0), color: .init(0, 0, 0, 1), texCoord: .init(0, 0)),
                .init(position: .init(-1, -1, 0), color: .init(0, 0, 0, 1), texCoord: .init(0, 1)),
                .init(position: .init(1, -1, 0), color: .init(0, 0, 0, 1), texCoord: .init(1, 1)),
                .init(position: .init(1, 1, 0), color: .init(0, 0, 0, 1), texCoord: .init(1, 0))
            ]

            let indexBufferDescriptor = IndexBufferU16Descriptor()
            indexBufferDescriptor.content = [0, 1, 2, 2, 3, 0]

            let descriptor = IndexedMesh.Descriptor()
            descriptor.vertexBufferDescriptors = [vertextBufferDescriptor]
            descriptor.indexBufferDescriptor = indexBufferDescriptor
            descriptor.toporogy = .triangle

            return indexedMeshFactory.make(descriptor)
        }()
    }
    
    func draw(
        toColor: MTLRenderPassColorAttachmentDescriptor,
        using commandBuffer: MTLCommandBuffer,
        source: MTLTexture
    ) {
        let encoder = {
            renderPassDescriptor.colorAttachments[0] = toColor
            return commandBuffer.makeRenderCommandEncoderWithSafe(descriptor: renderPassDescriptor)
        }()
        
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setFragmentTexture(source, index: 0)
        encoder.drawIndexedMesh(indexedMesh)
        encoder.endEncoding()
    }
    
    func debugFrameStatus(){
        gpu.debugCountreSample(from: counterSampleBuffer)
    }
}
