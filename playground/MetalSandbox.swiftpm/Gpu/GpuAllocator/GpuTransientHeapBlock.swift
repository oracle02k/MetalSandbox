import Metal

class GpuTypedTransientHeapBlock<T>: GpuBufferRegion {
    let raw: GpuTransientHeapBlock
    var buffer: MTLBuffer { raw.buffer }
    var begin: Int { raw.begin }
    var end: Int { raw.end }
    var size: Int { raw.size }
    
    init(raw: GpuTransientHeapBlock) {
        self.raw = raw
    }
    
    func write(value: T) {
        raw.write(value: value)
    }
    
    func write(from array: [T]) {
        raw.write(from: array)
    }
    
    func typedBufferCount() -> Int {
        return raw.typedBufferCount(T.self)
    }
    
    func withTypedPointer(_ body: (UnsafeMutablePointer<T>) -> Void) {
        raw.withTypedPointer(T.self, body)
    }
    
    func withTypedBuffer(_ body: (UnsafeMutableBufferPointer<T>) -> Void) {
        raw.withTypedBuffer(T.self, body)
    }
}

/// メモリアロケーション情報
class GpuTransientHeapBlock: GpuBufferRegion {
    let buffer: MTLBuffer
    let begin: Int
    let end: Int
    var size: Int { end - begin }
    
    init(buffer: MTLBuffer, begin: Int, end: Int) {
        self.buffer = buffer
        self.begin = begin
        self.end = end
    }
    
    /// Internal helper to get typed pointer
    private func typedPointer<T>() -> UnsafeMutablePointer<T> {
        buffer.contents().advanced(by: begin).assumingMemoryBound(to: T.self)
    }
    
    /// Write a single value to the buffer
    func write<T>(value: T) {
        guard MemoryLayout<T>.size <= size else {
            appFatalError("Write failed: value size exceeds buffer size (\(MemoryLayout<T>.size) > \(size))")
        }
        typedPointer().pointee = value
    }
    
    /// Write an array to the buffer (equivalent to memcpy)
    func write<T>(from array: [T]) {
        let requiredSize = MemoryLayout<T>.stride * array.count
        guard requiredSize <= size else {
            appFatalError("Write failed: array size exceeds buffer size (\(requiredSize) > \(size))")
        }
        
        _ = array.withUnsafeBytes { srcPointer in
            memcpy(buffer.contents().advanced(by: begin), srcPointer.baseAddress!, requiredSize)
        }
    }
    
    func typedBufferCount<T>(_ type: T.Type = T.self) -> Int {
        return size / MemoryLayout<T>.stride
    }
    
    /// Use a typed pointer for a single element
    func withTypedPointer<T>(_ type: T.Type = T.self, _ body: (UnsafeMutablePointer<T>) -> Void) {
        guard size >= MemoryLayout<T>.stride else {
            appFatalError("Mapping failed: buffer size is too small for type \(T.self) (\(size) < \(MemoryLayout<T>.stride))")
        }
        body(typedPointer())
    }
    
    /// Use a typed pointer for multiple elements
    func withTypedBuffer<T>(_ type: T.Type = T.self, _ body: (UnsafeMutableBufferPointer<T>) -> Void) {
        let count = size / MemoryLayout<T>.stride
        guard count > 0 else {
            appFatalError("Mapping failed: invalid buffer size for type \(T.self) (\(size) < \(MemoryLayout<T>.stride))")
        }
        
        let buffer = UnsafeMutableBufferPointer<T>(start: typedPointer(), count: count)
        body(buffer)
    }
}
