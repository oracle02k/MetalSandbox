import Metal

protocol RenderPipeline {
    associatedtype RenderPassConfigurator: RenderPassConfigurationProvider
    associatedtype Dispatcher: RenderCommandDispatcher
    func bind(to encoder: MTLRenderCommandEncoder)
}

protocol RenderPipelineFactorizeProvider {
    associatedtype RenderPassConfigurator: RenderPassConfigurationProvider
}
