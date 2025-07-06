import Metal

final class GpuTaskQueue {
    private let gpu: GpuContext
    private let dispatchQueue: DispatchQueue
    private let label: String
    
    init(gpu: GpuContext, name: String = "com.MetalSandbox.GpuTaskQueue") {
        self.gpu = gpu
        self.dispatchQueue = DispatchQueue(label: name, qos: .userInitiated, attributes: .concurrent)
        self.label = name
    }
    
    /// 非同期にGPUコマンドバッファを作成・実行
    func enqueue(_ label: String? = nil,
                 _ encode: @escaping (MTLCommandBuffer) -> Void,
                 onComplete: ((MTLCommandBuffer) -> Void)? = nil) {
        dispatchQueue.async { [self] in
            let commandBuffer = gpu.makeCommandBuffer()
            if let lbl = label {
                commandBuffer.label = lbl
            }
            
            encode(commandBuffer)
            
            if let onComplete = onComplete {
                commandBuffer.addCompletedHandler { cb in
                    onComplete(cb)
                }
            }
            
            commandBuffer.commit()
        }
    }
}
