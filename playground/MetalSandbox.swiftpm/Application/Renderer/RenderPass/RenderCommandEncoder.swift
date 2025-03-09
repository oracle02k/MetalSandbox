import Metal

final class RenderCommandEncoder<T:RenderPassConfigurationProvider>{
    let encoder: MTLRenderCommandEncoder
    let renderPipelines: T.RenderPipelines
    
    init(encoder: MTLRenderCommandEncoder, renderPipelines: T.RenderPipelines) {
        self.encoder = encoder
        self.renderPipelines = renderPipelines
    }
    
    func use<U: RenderPipeline>(_ type:U.Type, body:(U.Dispatcher)->Void ) where U.RenderPassConfigurator == T {
        let renderPipeline = renderPipelines.resolve(type)
        renderPipeline.bind(to: encoder)
        body(U.Dispatcher(encoder: encoder))
    }
    
    func endEncoding(){
        encoder.endEncoding()
    }
}
