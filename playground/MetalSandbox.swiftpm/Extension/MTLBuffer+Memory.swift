import SwiftUI

extension MTLBuffer {
    func bindArray<T>(length: Int = 1) -> [T] {
        let rawbufferSize = MemoryLayout<T>.stride * length
        let rawPointer = self.contents()
        let typedPointer = rawPointer.bindMemory(to: T.self, capacity: rawbufferSize)
        let bufferedPointer = UnsafeBufferPointer(start: typedPointer, count: length)
        return Array(bufferedPointer)
    }
}
