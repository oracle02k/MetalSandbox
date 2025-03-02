import Metal

protocol RenderPipeline {
    associatedtype Dispatcher:RenderCommandDispatcher
    func bind(to encoder: MTLRenderCommandEncoder)
}
