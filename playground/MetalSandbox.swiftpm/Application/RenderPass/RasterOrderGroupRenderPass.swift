import MetalKit

class RasterOrderGroupRenderPass {
    struct Vertex {
        var position: simd_float3
        var color: simd_float4
        var texCoord: simd_float2
    }
    
    private let gpu: GpuContext
    private let indexedMeshFactory: IndexedMesh.Factory
    private lazy var indexedMesh: IndexedMesh = uninitialized()
    private lazy var indexedMesh2: IndexedMesh = uninitialized()
    private lazy var indexedMesh3: IndexedMesh = uninitialized()
    private lazy var rasterOrderGroup0: MTLRenderPipelineState = uninitialized()
    private lazy var rasterOrderGroup1: MTLRenderPipelineState = uninitialized()
    private lazy var renderPassDescriptor: MTLRenderPassDescriptor = uninitialized()
    private lazy var counterSampleBuffer: MTLCounterSampleBuffer? = uninitialized()
    private lazy var texture: MTLTexture = uninitialized()
    
    init(with gpu: GpuContext, indexedMeshFactory: IndexedMesh.Factory) {
        self.gpu = gpu
        self.indexedMeshFactory = indexedMeshFactory
    }
    
    func build() {
        rasterOrderGroup0 = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "Raster Order Group 0 Pipeline"
            descriptor.sampleCount = 1
            descriptor.vertexFunction = gpu.findFunction(by: .TexcoordVertexFuction)
            descriptor.fragmentFunction = gpu.findFunction(by: .RasterOrderGroup0Fragment)
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            return gpu.makeRenderPipelineState(descriptor)
        }()
        
        rasterOrderGroup1 = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "Raster Order Group 1 Pipeline"
            descriptor.sampleCount = 1
            descriptor.vertexFunction = gpu.findFunction(by: .TexcoordVertexFuction)
            descriptor.fragmentFunction = gpu.findFunction(by: .RasterOrderGroup1Fragment)
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
        }catch{
            appFatalError("faild to make texture.", error: error)
        }
        
        let vertices:[Vertex] = [
            .init(position: .init(-1, 1, 0), color: .init(0, 0, 0, 1), texCoord: .init(0, 0)),
            .init(position: .init(-1, -1, 0), color: .init(0, 0, 0, 1), texCoord: .init(0, 1)),
            .init(position: .init(1, -1, 0), color: .init(0, 0, 0, 1), texCoord: .init(1, 1)),
            .init(position: .init(1, 1, 0), color: .init(0, 0, 0, 1), texCoord: .init(1, 0))
        ]
        indexedMesh = makeQuad(vertices: vertices)
        
        let vertices2:[Vertex] = [
            .init(position: .init(-1 + 1, 1, 0), color: .init(0, 0, 0, 1), texCoord: .init(0, 0)),
            .init(position: .init(-1 + 1, -1, 0), color: .init(0, 0, 0, 1), texCoord: .init(0, 1)),
            .init(position: .init(1 + 1, -1, 0), color: .init(0, 0, 0, 1), texCoord: .init(1, 1)),
            .init(position: .init(1 + 1, 1, 0), color: .init(0, 0, 0, 1), texCoord: .init(1, 0))
        ]
        indexedMesh2 = makeQuad(vertices: vertices2)
        
        let vertices3:[Vertex] = [
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
    
    func debugFrameStatus() {
        gpu.debugCountreSample(from: counterSampleBuffer)
    }
}
