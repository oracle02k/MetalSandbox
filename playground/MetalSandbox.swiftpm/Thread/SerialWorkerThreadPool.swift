final class SerialWorkerThreadPool {
    private var workers: [SerialWorkerThread]
    
    init(name:String = "com.MetalSandbox.SerialWorkerThreadPool", threadCount: Int) {
        precondition(threadCount > 0)
        self.workers = (0..<threadCount).map { SerialWorkerThread(name: name, id: $0) }
    }
    
    /// 指定したインデックスのスレッドに処理をキューイング
    func enqueue(to index: Int, _ body: @escaping () -> Void) {
        guard workers.indices.contains(index) else {
            print("SerialWorkerThreadPool: invalid thread index \(index)")
            return
        }
        workers[index].enqueue(body)
    }
    
    /// 簡単なラウンドロビン風に処理を割り振る例
    private var roundRobinIndex = 0
    func enqueueRoundRobin(_ body: @escaping () -> Void) {
        let index = roundRobinIndex % workers.count
        roundRobinIndex += 1
        enqueue(to: index, body)
    }
}
