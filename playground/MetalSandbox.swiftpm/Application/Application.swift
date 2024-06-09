import MetalKit

final class Application
{
    let vertices: [Vertex] = [
        Vertex(position: float3(-1,1,0), color: float4(0,0,0,1), texCoord: float2(0,0)),
        Vertex(position: float3(-1,-1,0), color: float4(0,0,0,1), texCoord: float2(0,1)),
        Vertex(position: float3(1,-1,0), color: float4(0,0,0,1), texCoord: float2(1,1)),
        Vertex(position: float3(1,1,0), color: float4(0,0,0,1), texCoord: float2(1,0)),
    ]
    let indices: [UInt32] = [0,1,2,2,3,0]
    
    private let gpuContext: GpuContext
    private let renderObject: RenderObject
    
    private lazy var offscreenTexture: MTLTexture = uninitialized()
    private lazy var offscreenRenderPassDescriptor: MTLRenderPassDescriptor = uninitialized()
    private lazy var viewRenderPipelineStateId: Int = uninitialized()
    private lazy var vertexBuffer: MTLBuffer = uninitialized()
    private lazy var indexBuffer: MTLBuffer = uninitialized()
    
    init(_ gpuContext: GpuContext) {
        self.gpuContext = gpuContext
        self.renderObject = RenderObject(gpuContext)
    }
    
    func build()
    {
        offscreenTexture = {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2D
            descriptor.width = 320;
            descriptor.height = 320;
            descriptor.pixelFormat = .bgra8Unorm
            descriptor.usage = [.renderTarget, .shaderRead]
            return gpuContext.makeTexture(descriptor)
        }()
        
        offscreenRenderPassDescriptor = {
            let descriptor = MTLRenderPassDescriptor()
            descriptor.colorAttachments[0].texture = offscreenTexture
            descriptor.colorAttachments[0].loadAction = .clear
            descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            descriptor.colorAttachments[0].storeAction = .store
            return descriptor
        }()
        
        viewRenderPipelineStateId = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "View Render Pipeline"
            descriptor.sampleCount = 1
            descriptor.vertexFunction = gpuContext.findFunction(by:.TexcoordVertexFuction)
            descriptor.fragmentFunction = gpuContext.findFunction(by: .TexcoordFragmentFunction)
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            return gpuContext.buildAndRegisterRenderPipelineState(from: descriptor)
        }()
        
        vertexBuffer = gpuContext.makeBuffer(vertices)
        indexBuffer = gpuContext.makeBuffer(indices)
        
        renderObject.build()
    }
    
    func draw(viewDrawable: CAMetalDrawable, viewRenderPassDescriptor: MTLRenderPassDescriptor)
    {
        gpuContext.gpuDebugger.framInit()
        
        let command = gpuContext.makeRenderCommand(offscreenRenderPassDescriptor)
        renderObject.draw(command)
        command.commit()
    
        viewRenderPassDescriptor.colorAttachments[0].clearColor = .init(red: 1, green: 1, blue: 0, alpha: 1)
        let viewCommand = gpuContext.makeRenderCommand(viewRenderPassDescriptor)
        viewCommand.useRenderPipelineState(id: viewRenderPipelineStateId)
        viewCommand.setTexture(offscreenTexture, index: 0)
        viewCommand.drawIndexedTriangles(vertexBuffer: vertexBuffer, indexBuffer: indexBuffer, indexCount: indices.count)
        viewCommand.commit(with: viewDrawable)
     
    }
}
