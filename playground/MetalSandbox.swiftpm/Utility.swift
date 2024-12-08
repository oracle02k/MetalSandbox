import Foundation

public func synchronized(_ obj: AnyObject, closure: () -> Void) {
    objc_sync_enter(obj)
    closure()
    objc_sync_exit(obj)
}

// CPU使用率を0-1で取得
func getCPUUsage() -> Float {
    // カーネル処理の結果
    var result: Int32
    var threadList = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
    var threadCount = UInt32(MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<natural_t>.size)
    var threadInfo = thread_basic_info()

    // スレッド情報を取得
    result = withUnsafeMutablePointer(to: &threadList) {
        $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
            task_threads(mach_task_self_, $0, &threadCount)
        }
    }

    if result != KERN_SUCCESS { return 0 }

    // 各スレッドからCPU使用率を算出し合計を全体のCPU使用率とする
    return (0 ..< Int(threadCount))
        // スレッドのCPU使用率を取得
        .compactMap { index -> Float? in
            var threadInfoCount = UInt32(THREAD_INFO_MAX)
            result = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(threadList[index], UInt32(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }
            // スレッド情報が取れない = 該当スレッドのCPU使用率を0とみなす(基本nilが返ることはない)
            if result != KERN_SUCCESS { return nil }
            let isIdle = threadInfo.flags == TH_FLAGS_IDLE
            // CPU使用率がスケール調整済みのため`TH_USAGE_SCALE`で除算し戻す
            return !isIdle ? (Float(threadInfo.cpu_usage) / Float(TH_USAGE_SCALE)) : nil
        }
        // 合計算出
        .reduce(0, +)
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
