import Foundation

public func synchronized(_ obj: AnyObject, closure: () -> Void) {
    objc_sync_enter(obj)
    closure()
    objc_sync_exit(obj)
}

public func sizeof<T>(_ obj: T? = nil) -> Int {
    return MemoryLayout<T>.stride
}
