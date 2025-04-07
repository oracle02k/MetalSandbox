import Foundation

public func synchronized(_ obj: AnyObject, closure: () -> Void) {
    objc_sync_enter(obj)
    closure()
    objc_sync_exit(obj)
}

func getCPUUsage() -> Float {
    var activeUsage: Float = 0
    var result: Int32

    // Allocate space for thread list
    var threadList: thread_act_array_t?
    var threadCount = mach_msg_type_number_t()

    // Retrieve thread list and ensure memory is deallocated
    result = task_threads(mach_task_self_, &threadList, &threadCount)
    guard result == KERN_SUCCESS, let threadList = threadList else { return 0 }

    defer {
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threadList), vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.size))
    }

    // Calculate CPU usage for each thread
    for index in 0..<Int(threadCount) {
        var threadInfo = thread_basic_info()
        var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)

        result = withUnsafeMutablePointer(to: &threadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                thread_info(threadList[index], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
            }
        }

        // Skip this thread if information retrieval failed
        guard result == KERN_SUCCESS else { continue }

        let usage = (Float(threadInfo.cpu_usage) / Float(TH_USAGE_SCALE))
        if (threadInfo.flags & TH_FLAGS_IDLE) != TH_FLAGS_IDLE {
            activeUsage += usage
        }
    }

    return activeUsage
}

// 引数にenumで任意の単位を指定できるのが好ましい e.g. unit = .auto (デフォルト引数)
func getMemoryUsed() -> KByte? {
    // タスク情報を取得
    var info = mach_task_basic_info()
    // `info`の値からその型に必要なメモリを取得
    var count = UInt32(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) {
        task_info(mach_task_self_,
                  task_flavor_t(MACH_TASK_BASIC_INFO),
                  // `task_info`の引数にするためにInt32のメモリ配置と解釈させる必要がある
                  $0.withMemoryRebound(to: Int32.self, capacity: 1) { pointer in
                    UnsafeMutablePointer<Int32>(pointer)
                  }, &count)
    }
    // MB表記に変換して返却
    return result == KERN_SUCCESS ? info.resident_size / 1024 : nil
}

/// 任意の型 `T` をスタック管理するジェネリクスラッパー
class PropertyStack<T> {
    private var stack: [T] = []
    
    /// スタックの現在のトップを取得（デフォルト値あり）
    var current: T { stack.last! }
    
    /// 新しい値をスタックに追加
    func push(_ value: T) {
        stack.append(value)
    }
    
    /// 直前の状態に戻す（空にならないようにする）
    func pop() {
        if stack.count > 1 {
            stack.removeLast()
        }
    }
}

@propertyWrapper
struct Cached<Value> {
    private var storage: Value?
    private let compute: () -> Value
    
    init(wrappedValue: @autoclosure @escaping () -> Value) {
        self.compute = wrappedValue
    }
    
    var wrappedValue: Value {
        mutating get {
            if let value = storage {
                return value
            }
            let value = compute()
            storage = value
            return value
        }
    }
    
    mutating func reset() {
        storage = nil
    }
}

func measure<T>(_ label: String = "", block: () -> T) -> T {
    let start = DispatchTime.now()
    let result = block()
    let end = DispatchTime.now()
    let nano = Double(end.uptimeNanoseconds - start.uptimeNanoseconds)
    
    let display: String
    if nano >= 1_000_000_000 {
        display = String(format: "%.3f 秒", nano / 1_000_000_000)
    } else if nano >= 1_000_000 {
        display = String(format: "%.3f ms", nano / 1_000_000)
    } else if nano >= 1_000 {
        display = String(format: "%.3f µs", nano / 1_000)
    } else {
        display = String(format: "%.0f ns", nano)
    }
    
    print("\(label)処理時間: \(display)")
    return result
}
