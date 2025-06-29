import Metal

final class GpuRenderQueue {
    private let gpu: GpuContext
    private let dispatchQueue: DispatchQueue
    private let label: String
    private lazy var commandBuffer: MTLCommandBuffer = uninitialized()

    init(gpu: GpuContext, label: String = "com.MetalSandbox.GpuRenderQueue") {
        self.gpu = gpu
        self.dispatchQueue = DispatchQueue(label: label, qos: .userInitiated)
        self.label = label
    }
    
    func build(){
        commandBuffer = gpu.makeCommandBuffer()
    }
    
    func addCompletedHandler(_ body: @escaping (MTLCommandBuffer) -> Void){
        dispatchQueue.async { [self] in
            commandBuffer.addCompletedHandler(body)
        }
    }
    
    /// 非同期かつ直列にGPUコマンドバッファを作成・実行
    func enqueue(_ encode: @escaping (MTLCommandBuffer) -> Void) {
        dispatchQueue.async{ [self] in
            encode(commandBuffer)
        }
    }
    
    func commitAndNext(){
        dispatchQueue.async{ [self] in
            commandBuffer.commit()
            commandBuffer = gpu.makeCommandBuffer()
        }
    }
}
