import Metal

final class PassthroughtTextureRenderPipeline: RenderPipeline {
    typealias RenderPassConfigurator = BasicRenderPassConfigurator
    typealias Functions = RenderPassConfigurator.Functions
    typealias Dispatcher = PassthroughtTextureRenderCommandDispatcher

    let colorIndex = RenderPassConfigurator.RenderTargets.Color.rawValue
    lazy var pipelineState: MTLRenderPipelineState = uninitialized()

    func build(gpu: GpuContext, functions: Functions, colorPixelFormat: MTLPixelFormat) {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "\(Self.self)"
        descriptor.vertexFunction =  functions.find(by: .PassthroughtTextureVS)
        descriptor.fragmentFunction = functions.find(by: .PassthroughtTextureFS)
        descriptor.colorAttachments[colorIndex].pixelFormat = colorPixelFormat
        descriptor.depthAttachmentPixelFormat = .invalid// .depth32Float
        descriptor.vertexDescriptor = Dispatcher.Vertex.makeVertexDescriptor()
        pipelineState = gpu.makeRenderPipelineState(descriptor)
    }

    func bind(to encoder: MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(pipelineState)
    }
}
