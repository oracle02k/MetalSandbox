import SwiftUI

class RenderObject {
    private let vertices: [Vertex] = [
        Vertex(position: float3(0,1,0), color: float4(1,0,0,1), texCoord: float2(0,0)),
        Vertex(position: float3(-1,-1,0), color: float4(0,1,0,1), texCoord: float2(0,0)),
        Vertex(position: float3(1,-1,0), color: float4(0,0,1,1), texCoord: float2(0,0)),
    ]
    
    private lazy var renderPipelineStateId: Int = uninitialized()
    
    func build(_ gpuContext: GpuContext) {
        renderPipelineStateId = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "Offscreen Render Pipeline"
            descriptor.sampleCount = 1
            descriptor.vertexFunction = gpuContext.findFunction(by: .BasicVertexFunction)
            descriptor.fragmentFunction = gpuContext.findFunction(by: .BasicFragmentFunction)
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            return gpuContext.buildAndRegisterRenderPipelineState(from: descriptor)
        }()
    }
    
    func draw(_ command: RenderCommand) {
        command.useRenderPipelineState(id: renderPipelineStateId)
        command.drawTriangleIndices(vertices, indices: [0,1,2])
    //    command.drawTriangles(vertices)
    }
}
