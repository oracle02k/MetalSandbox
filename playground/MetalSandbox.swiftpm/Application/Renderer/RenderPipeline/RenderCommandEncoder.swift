import Metal

final class RenderCommandEncoder{
    let encoder: MTLRenderCommandEncoder
    let renderPipelineContainer: RenderPipelineContainer
    
    init(encoder: MTLRenderCommandEncoder, renderPipelineContainer: RenderPipelineContainer) {
        self.encoder = encoder
        self.renderPipelineContainer = renderPipelineContainer
    }
    
    func use<T: RenderPipeline>(_ type:T.Type, body:(T.Dispatcher)->Void ){
        let renderPipeline = renderPipelineContainer.resolve(type)
        renderPipeline.bind(to: encoder)
        body(T.Dispatcher(encoder: encoder))
    }
    
    func endEncoding(){
        encoder.endEncoding()
    }
}
