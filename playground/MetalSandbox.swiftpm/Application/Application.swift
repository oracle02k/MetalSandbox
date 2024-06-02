import MetalKit

final class Application
{
    let screenVertices: [Vertex] = [
        Vertex(position: float3(-1,1,0), color: float4(0,0,0,1), texCoord: float2(0,0)),
        Vertex(position: float3(-1,-1,0), color: float4(0,0,0,1), texCoord: float2(0,1)),
        Vertex(position: float3(1,-1,0), color: float4(0,0,0,1), texCoord: float2(1,1)),
        Vertex(position: float3(1,-1,0), color: float4(0,0,0,1), texCoord: float2(1,1)),
        Vertex(position: float3(1,1,0), color: float4(0,0,0,1), texCoord: float2(1,0)),
        Vertex(position: float3(-1,1,0), color: float4(0,0,0,1), texCoord: float2(0,0)),
    ]
    let screenVertices2: [Vertex] = [
        Vertex(position: float3(-1,1,0), color: float4(0,0,0,1), texCoord: float2(0,0)),
        Vertex(position: float3(-1,-1,0), color: float4(0,0,0,1), texCoord: float2(0,1)),
        Vertex(position: float3(1,-1,0), color: float4(0,0,0,1), texCoord: float2(1,1)),
        Vertex(position: float3(1,1,0), color: float4(0,0,0,1), texCoord: float2(1,0)),
    ]
    
    private let gpuContext: GpuContext
    private let renderObject: RenderObject
    
    private lazy var offscreenTexture: MTLTexture = uninitialized()
    private lazy var offscreenRenderPassDescriptor: MTLRenderPassDescriptor = uninitialized()
    private lazy var viewRenderPipelineStateId: Int = uninitialized()
    
    init(_ gpuContext: GpuContext) {
        self.gpuContext = gpuContext
        self.renderObject = RenderObject()
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
        
        renderObject.build(gpuContext)
    }
    
    func draw(viewDrawable: CAMetalDrawable, viewRenderPassDescriptor: MTLRenderPassDescriptor)
    {
        gpuContext.gpuDebugger.framInit()
        
        let command = gpuContext.makeRenderCommand(offscreenRenderPassDescriptor)
        renderObject.draw(command)
        command.commit()
    
        let viewCommand = gpuContext.makeRenderCommand(viewRenderPassDescriptor)
        viewCommand.useRenderPipelineState(id: viewRenderPipelineStateId)
        viewCommand.setTexture(offscreenTexture, index: 0)
      //  viewCommand.drawTriangles(screenVertices)
        viewCommand.drawTriangleIndices(screenVertices2, indices: [0,1,2,2,3,0])
        viewCommand.commit(with: viewDrawable)
    }
}
