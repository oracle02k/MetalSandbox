import Metal

final class GpuRenderQueue {
    private let gpu: GpuContext
    private let threadPool: SerialWorkerThreadPool
    private lazy var commandBuffer: MTLCommandBuffer = uninitialized()

    init(gpu: GpuContext, name: String = "com.MetalSandbox.GpuRenderQueue") {
        self.gpu = gpu
        self.threadPool = SerialWorkerThreadPool(name: name, threadCount: 1)
    }
    
    func build(){
        commandBuffer = gpu.makeCommandBuffer()
    }
    
    func addCompletedHandler(_ body: @escaping (MTLCommandBuffer) -> Void){
        threadPool.enqueue(to: 0){ [self] in
            commandBuffer.addCompletedHandler(body)
        }
    }
    
    /// 非同期かつ直列にGPUコマンドバッファを作成・実行
    func enqueue(_ encode: @escaping (MTLCommandBuffer) -> Void) {
        threadPool.enqueue(to: 0){ [self] in
            encode(commandBuffer)
        }
    }
    
    func commitAndNext(){
        threadPool.enqueue(to: 0){ [self] in
            commandBuffer.commit()
            commandBuffer = gpu.makeCommandBuffer()
        }
    }
}
