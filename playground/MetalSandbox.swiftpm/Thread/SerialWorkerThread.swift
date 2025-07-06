import Foundation

final class SerialWorkerThread: NSObject {
    private var thread: Thread!
    private var workItems: [() -> Void] = []
    private let lock = NSLock()
    
    let id: Int
    
    init(name:String = "com.MetalSandbox.SerialWorkerThread", id: Int) {
        self.id = id
        
        super.init()
        thread = Thread(target: self, selector: #selector(threadMain), object: nil)
        thread.name = (name + " [\(id)]")
        thread.start()
    }
    
    @objc private func threadMain() {
        autoreleasepool {
            while !Thread.current.isCancelled {
                RunLoop.current.run(mode: .default, before: .distantFuture)
            }
        }
    }
    
    func enqueue(_ body: @escaping () -> Void) {
        lock.lock()
        workItems.append(body)
        lock.unlock()
        perform(#selector(runNext), on: thread, with: nil, waitUntilDone: false)
    }
    
    @objc private func runNext() {
        lock.lock()
        let items = workItems
        workItems.removeAll()
        lock.unlock()
        
        for item in items {
            autoreleasepool {
                item()
            }
        }
    }
    
    deinit {
        thread.cancel()
    }
}
