import Metal

class BasicRenderPass {
    enum RenderTargetIndices: Int {
        case Color = 0
    }

    let FunctionFileName = "triangle.txt"    
    enum FunctionNames: String, CaseIterable {
        case VertexShader = "triangle::vertex_shader"
        case FragmentShader = "triangle::fragment_shader"
    }

    typealias Functions = FunctionContainer<FunctionNames>
    
    private let functions: Functions
    private let gpu: GpuContext
    
    private let triangleRenderPipeline = TriangleRenderPipeline()
    private let renderPipelineContainer = RenderPipelineContainer()
    private var counterSampler: CounterSampler? = nil
    
    init (with gpu: GpuContext, functions: Functions) {
        self.gpu = gpu
        self.functions = functions
    }

    func build(colorPixelFormat: MTLPixelFormat) {
        functions.build(fileName: FunctionFileName)
        
        let pipeline = TriangleRenderPipeline()
        pipeline.build(gpu: gpu, functions: functions, colorPixelFormat: colorPixelFormat)
        renderPipelineContainer.register(pipeline)
    }
    
    func makeEncoder(
        colorDescriptor: MTLRenderPassColorAttachmentDescriptor,
        using commandBuffer: MTLCommandBuffer
    ) -> RenderCommandEncoder {
        let encoder = {
            let descriptor = MTLRenderPassDescriptor()
            descriptor.colorAttachments[RenderTargetIndices.Color.rawValue] = colorDescriptor
            counterSampler?.attachToRenderPass(descriptor: descriptor, name: "basic render pass")
            return commandBuffer.makeRenderCommandEncoderWithSafe(descriptor: descriptor)
        }()
        
        return RenderCommandEncoder(encoder: encoder, renderPipelineContainer: renderPipelineContainer)
    }
    
    func attachCounterSampler(_ counterSampler: CounterSampler?){
        self.counterSampler = counterSampler
    }
}
