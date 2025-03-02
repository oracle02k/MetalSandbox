
class RenderPipelineContainer {
    var pipelines: [ObjectIdentifier: any RenderPipeline] = [:]
    
    func register<T: RenderPipeline>(_ instance: T) {
        pipelines[ObjectIdentifier(T.self)] = instance
    }
    
    func resolve<T: RenderPipeline>(_ type: T.Type) -> T {
        return pipelines[ObjectIdentifier(T.self)] as! T
    }
}
