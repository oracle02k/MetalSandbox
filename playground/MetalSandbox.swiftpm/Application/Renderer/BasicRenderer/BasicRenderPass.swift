import Metal

enum BasicRenderPassConfigurator: RenderPassConfigurationProvider {
    typealias Functions = FunctionContainer<BasicRenderPassFunctionTable>
    typealias RenderPipelines = RenderPipelineContainer<Self>
    typealias RenderPipelineFactory = BasicRenderPipelineFactory
    typealias DescriptorSpec = BasicRenderPassDescriptorSpec
    typealias CommandEncoderFactory = RenderCommandEncoderFactory<Self>
    
    enum RenderTargets: Int {
        case Color = 0
    }
    
    static let Name = "BasicRenderPass"
    static let ColorFormat:MTLPixelFormat = .bgra8Unorm
}

enum BasicRenderPassFunctionTable: String, FunctionTableProvider {
    static let FileName = "triangle.txt"
    case VertexShader = "triangle::vertex_shader"
    case FragmentShader = "triangle::fragment_shader"
}

class BasicRenderPipelineFactory: RenderPipelineFactorizeProvider {
    typealias RenderPassConfigurator = BasicRenderPassConfigurator

    func build(with gpu: GpuContext, functions: RenderPassConfigurator.Functions) -> RenderPassConfigurator.RenderPipelines {
        let container = RenderPassConfigurator.RenderPipelines()
        
        container.register({
            let pipeline = TriangleRenderPipeline()
            pipeline.build(gpu: gpu, functions: functions, colorPixelFormat: RenderPassConfigurator.ColorFormat)
            return pipeline
        }())
        
        return container
    }
}

struct BasicRenderPassDescriptorSpec: RenderPassDescriptorSpecProvider {
    typealias Configurator =  BasicRenderPassConfigurator
    
    func isSatisfiedBy(_ descriptor: MTLRenderPassDescriptor) -> Bool {
        let colorTexture = descriptor.colorAttachments[Configurator.RenderTargets.Color.rawValue].texture
        return colorTexture?.pixelFormat == Configurator.ColorFormat
    }
}
