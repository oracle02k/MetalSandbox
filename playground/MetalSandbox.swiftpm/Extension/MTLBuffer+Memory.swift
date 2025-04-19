import SwiftUI

extension MTLBuffer {
    func bindArray<T>(_ type: T.Type, length: Int = 1) -> [T] {
        let rawbufferSize = MemoryLayout<T>.stride * length
        let rawPointer = self.contents()
        let typedPointer = rawPointer.bindMemory(to: T.self, capacity: rawbufferSize)
        let bufferedPointer = UnsafeBufferPointer(start: typedPointer, count: length)
        return Array(bufferedPointer)
    }

    func write<T>(index: Int, data: T) {
        let length = (index + 1)
        let rawbufferSize = MemoryLayout<T>.stride * length
        let rawPointer = self.contents()
        let typedPointer = rawPointer.bindMemory(to: T.self, capacity: rawbufferSize)
        let bufferedPointer = UnsafeMutableBufferPointer(start: typedPointer, count: length)
        bufferedPointer[index] = data
    }
}
