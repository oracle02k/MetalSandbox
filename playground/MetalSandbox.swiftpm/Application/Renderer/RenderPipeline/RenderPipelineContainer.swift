class RenderPipelineContainer<T:RenderPassConfigurationProvider> {
    var pipelines: [ObjectIdentifier: any RenderPipeline] = [:]
    
    func register<U: RenderPipeline>(_ instance: U) where U.RenderPassConfigurator == T{
        pipelines[ObjectIdentifier(U.self)] = instance
    }
    
    func resolve<U: RenderPipeline>(_ type: U.Type) -> U where U.RenderPassConfigurator == T{
        return pipelines[ObjectIdentifier(U.self)] as! U
    }
}
