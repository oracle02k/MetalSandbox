import MetalKit

class Application
{
    let renderer: Renderer
    let vertices: [Vertex] = [
        Vertex(position: float3(0,1,0), color: float4(1,0,0,1), texCoord: float2(0,0)),
        Vertex(position: float3(-1,-1,0), color: float4(0,1,0,1), texCoord: float2(0,0)),
        Vertex(position: float3(1,-1,0), color: float4(0,0,1,1), texCoord: float2(0,0)),
    ]
    
    let screenVertices: [Vertex] = [
        Vertex(position: float3(-1,1,0), color: float4(0,0,0,1), texCoord: float2(0,0)),
        Vertex(position: float3(-1,-1,0), color: float4(0,0,0,1), texCoord: float2(0,1)),
        Vertex(position: float3(1,-1,0), color: float4(0,0,0,1), texCoord: float2(1,1)),
        Vertex(position: float3(1,-1,0), color: float4(0,0,0,1), texCoord: float2(1,1)),
        Vertex(position: float3(1,1,0), color: float4(0,0,0,1), texCoord: float2(1,0)),
        Vertex(position: float3(-1,1,0), color: float4(0,0,0,1), texCoord: float2(0,0)),
    ]
    
    init(_ renderer: Renderer) {
        self.renderer = renderer
    }
    
    func draw(viewDrawable: CAMetalDrawable, viewRenderPassDescriptor: MTLRenderPassDescriptor)
    {
        let texture = {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2D
            descriptor.width = 320;
            descriptor.height = 320;
            descriptor.pixelFormat = .bgra8Unorm
            descriptor.usage = [.renderTarget, .shaderRead]
            return renderer.makeTexture(descriptor)
        }()
        
        let offscreenRenderPipelineState = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "Offscreen Render Pipeline"
            descriptor.sampleCount = 1
            descriptor.vertexFunction = try! renderer.makeFunction(name: "basic_vertex_function")
            descriptor.fragmentFunction = try! renderer.makeFunction(name: "basic_fragment_function") 
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            return try! renderer.makePipelineState(descriptor)
        }()
        
        let offscreenRenderPassDescriptor = {
            let descriptor = MTLRenderPassDescriptor()
            descriptor.colorAttachments[0].texture = texture
            descriptor.colorAttachments[0].loadAction = .clear
            descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            descriptor.colorAttachments[0].storeAction = .store
            return descriptor
        }()
        
        let command = renderer.makeRenderCommand(offscreenRenderPassDescriptor, offscreenRenderPipelineState)
        command.drawTriangles(vertices)
        command.commit()
        
        let viewRenderPipelineState = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "View Render Pipeline"
            descriptor.sampleCount = 1
            descriptor.vertexFunction = try! renderer.makeFunction(name: "texcoord_vertex_function")
            descriptor.fragmentFunction = try! renderer.makeFunction(name: "texcoord_fragment_function") 
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
            return try! renderer.makePipelineState(descriptor)
        }()
        
        let viewCommand = renderer.makeRenderCommand(viewRenderPassDescriptor, viewRenderPipelineState)
        viewCommand.setTexture(texture, index: 0)
        viewCommand.drawTriangles(screenVertices)
        viewCommand.commit(with: viewDrawable)
    }
}
