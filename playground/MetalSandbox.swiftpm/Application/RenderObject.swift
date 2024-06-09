import SwiftUI

class RenderObject {
    struct Vertex {
        var position: float3
        var color: float4
        var texCoord: float2
    }

    private let gpuContext: GpuContext
    private lazy var primitives: Primitives = uninitialized()
    private lazy var renderPipelineState: MTLRenderPipelineState = uninitialized()

    init (_ gpuContext: GpuContext) {
        self.gpuContext = gpuContext
    }

    func build() {
        renderPipelineState = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "Basic Render Pipeline"
            descriptor.sampleCount = 1
            descriptor.vertexFunction = gpuContext.findFunction(by: .BasicVertexFunction)
            descriptor.fragmentFunction = gpuContext.findFunction(by: .BasicFragmentFunction)
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            return gpuContext.makeRenderPipelineState(descriptor)
        }()

        primitives = {
            let vertexBufferDescriptor = VertexBufferDescriptor<Vertex>()
            vertexBufferDescriptor.content = [
                .init(position: float3(0, 1, 0), color: float4(1, 0, 0, 1), texCoord: float2(0, 0)),
                .init(position: float3(-1, -1, 0), color: float4(0, 1, 0, 1), texCoord: float2(0, 0)),
                .init(position: float3(1, -1, 0), color: float4(0, 0, 1, 1), texCoord: float2(0, 0))
            ]

            let descriptor = PrimitivesDescriptor()
            descriptor.vertexBufferDescriptors = [vertexBufferDescriptor]
            descriptor.vertexCount = vertexBufferDescriptor.count
            descriptor.toporogy = .triangle

            return gpuContext.makePrimitives(descriptor)
        }()
    }

    func draw(_ command: RenderCommand) {
        command.useRenderPipelineState(renderPipelineState)
        command.drawPrimitives(primitives)
    }
}
