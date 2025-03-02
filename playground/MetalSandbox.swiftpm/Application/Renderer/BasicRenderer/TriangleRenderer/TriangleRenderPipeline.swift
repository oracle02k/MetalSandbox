import Metal

final class TriangleRenderPipeline: RenderPipeline{
    typealias Dispatcher = TriangleRenderCommandDispatcher
    lazy var pipelineState: MTLRenderPipelineState = uninitialized()
    
    func build(gpu:GpuContext, functions:BasicRenderPass.Functions, colorPixelFormat:MTLPixelFormat){
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = String(describing: self)
        descriptor.vertexFunction = functions.find(by: .VertexShader)
        descriptor.fragmentFunction = functions.find(by: .FragmentShader)
        descriptor.colorAttachments[BasicRenderPass.RenderTargetIndices.Color.rawValue].pixelFormat = colorPixelFormat
        descriptor.depthAttachmentPixelFormat = .invalid// .depth32Float
        pipelineState = gpu.makeRenderPipelineState(descriptor)
    }
    
    func bind(to encoder: MTLRenderCommandEncoder){
        encoder.setRenderPipelineState(pipelineState)
    }
}
