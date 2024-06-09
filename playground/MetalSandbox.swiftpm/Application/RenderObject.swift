import SwiftUI

class BasicRenderPipelineState {
    struct Vertex {
        var position: float3
        var color: float4
        var texCoord: float2
    }
    
    typealias VBDescriptor = VertexBufferDescriptor<Vertex>

    private let gpuContext: GpuContext
    private(set) lazy var renderPipelineStateId: Int = uninitialized()
    
    init(_ gpuContext: GpuContext) {
        self.gpuContext = gpuContext
    }

    func build() {
        renderPipelineStateId = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "Basic Render Pipeline"
            descriptor.sampleCount = 1
            descriptor.vertexFunction = gpuContext.findFunction(by: .BasicVertexFunction)
            descriptor.fragmentFunction = gpuContext.findFunction(by: .BasicFragmentFunction)
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            return gpuContext.buildAndRegisterRenderPipelineState(from: descriptor)
        }()
    }
}

class RenderObject {
    
    private let gpuContext: GpuContext
    private let basicRenderPipelineState: BasicRenderPipelineState
    private lazy var primitives: Primitives = uninitialized()
    
    init (_ gpuContext: GpuContext) {
        self.gpuContext = gpuContext
        basicRenderPipelineState = BasicRenderPipelineState(gpuContext)
    }
    
    func build() {
        basicRenderPipelineState.build()
        primitives = {
            let vertexBufferDescriptor = BasicRenderPipelineState.VBDescriptor()
            vertexBufferDescriptor.content = [
                .init(position: float3(0,1,0), color: float4(1,0,0,1), texCoord: float2(0,0)),
                .init(position: float3(-1,-1,0), color: float4(0,1,0,1), texCoord: float2(0,0)),
                .init(position: float3(1,-1,0), color: float4(0,0,1,1), texCoord: float2(0,0)),
            ]
            
            let descriptor = PrimitiveDescriptor()
            descriptor.vertexBufferDescriptors = [vertexBufferDescriptor]
            descriptor.vertexCount = vertexBufferDescriptor.count
            descriptor.toporogy = .triangle
            
            return gpuContext.makePrimitives(descriptor)
        }()    
    }
    
    func draw(_ command: RenderCommand) {
        command.useRenderPipelineState(id: basicRenderPipelineState.renderPipelineStateId)
        command.drawPrimitives(primitives)
    }
}
