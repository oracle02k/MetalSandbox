import MetalKit

class TypedBuffer<T> {
    let rawBuffer: MTLBuffer
    let count: Int
    let bufferedPointer: UnsafeMutableBufferPointer<T>
    
    init(rawBuffer: MTLBuffer, count: Int) {
        self.rawBuffer = rawBuffer
        self.count = count
        let rawbufferSize = MemoryLayout<T>.stride * count
        let rawPointer = rawBuffer.contents()
        let typedPointer = rawPointer.bindMemory(to: T.self, capacity: rawbufferSize)
        bufferedPointer = UnsafeMutableBufferPointer(start: typedPointer, count: count)
    }
    
    var contents: T {
        get { bufferedPointer[0] }
        set { bufferedPointer[0] = newValue }
    }
    
    subscript(index: Int) -> T {
        get { bufferedPointer[index] }
        set { bufferedPointer[index] = newValue }
    }
}
