import Metal

struct GpuFrameEnv {
    let sharedAllocatorSize: Int
    let privateAllocatorSize: Int
}

class GpuFrameContext {
    let frameInFlight = 3
    var sharedAllocator: GpuTransientAllocator { sharedAllocators[currentFrameIndex] }
    var privateAllocator: GpuTransientAllocator { privateAllocators[currentFrameIndex] }
    
    private let gpu: GpuContext
    private(set) var currentFrameIndex = 0
    private var sharedAllocators = [GpuTransientAllocator]()
    private var privateAllocators = [GpuTransientAllocator]()
    
    init(gpu: GpuContext){
        self.gpu = gpu
    }
    
    func build(env: GpuFrameEnv){
        for _ in 0..<frameInFlight{
            sharedAllocators.append(
                .init(gpu.makeBuffer(length: env.sharedAllocatorSize, options: .storageModeShared))
            )
            privateAllocators.append(
                .init(gpu.makeBuffer(length: env.privateAllocatorSize, options: .storageModePrivate))
            )
        }
    }
    
    func next(){
        currentFrameIndex = (currentFrameIndex + 1) % frameInFlight
        sharedAllocator.clear()
        privateAllocator.clear()
    }
    
    func makeFrameRenderCommandBuilder() -> GpuRenderCommandBuilder {
        return GpuRenderCommandBuilder(
            allocator: sharedAllocator,
            renderCommandRepository: GpuRenderCommandRepository(),
            functions: gpu.functions,
            renderStateResolver: gpu.renderStateResolver
        )
    }
    
    func buildFrameRenderCommand(_ body: (GpuRenderCommandBuilder) -> Void) -> GpuRenderCommandDispatchParams {
        let builder = makeFrameRenderCommandBuilder()
        body(builder)
        return builder.makeDispatchParams()
    }
}
