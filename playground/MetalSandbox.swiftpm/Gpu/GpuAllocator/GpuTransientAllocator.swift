import Metal

/// フレームごとの一時的なデータを管理する Metal 向けアロケータ
class GpuTransientAllocator {
    static let defaultAlignment = 16

    private let buffer: MTLBuffer
    private var bufferSize: Int { buffer.length }
    private var bufferOffset: Int = 0
    private var debugAllocated = [GpuTransientHeapBlock]()

    init(_ buffer: MTLBuffer) {
        self.buffer = buffer
    }

    func allocateTypedPointer<T>(
        of type: T.Type = T.self,
        length: Int = 1,
        alignment: Int = defaultAlignment,
        body: (UnsafeMutablePointer<T>) -> Void
    ) -> GpuTypedTransientHeapBlock<T> {
        let heapBlock = allocate(of: T.self, length: length)
        heapBlock.withTypedPointer(body)

        return heapBlock
    }

    func allocateTypedBuffer<T>(
        of type: T.Type = T.self,
        length: Int = 1,
        alignment: Int = defaultAlignment,
        body: (UnsafeMutableBufferPointer<T>) -> Void
    ) -> GpuTypedTransientHeapBlock<T> {
        let heapBlock = allocate(of: T.self, length: length, alignment: alignment)
        heapBlock.withTypedBuffer(body)

        return heapBlock
    }

    func allocate<T>(
        of type: T.Type = T.self,
        length: Int = 1,
        alignment: Int = defaultAlignment
    ) -> GpuTypedTransientHeapBlock<T> {
        return  GpuTypedTransientHeapBlock(raw: allocate(size: MemoryLayout<T>.stride * length))
    }

    /// `size` バイトのメモリを確保し、バッファとオフセットを返す
    func allocate(size: Int, alignment: Int = defaultAlignment ) -> GpuTransientHeapBlock {
        let alignedOffset = (bufferOffset + alignment - 1) & ~(alignment - 1)

        // バッファサイズを超えたら確保できない
        if alignedOffset + size > bufferSize {
            appFatalError("[GpuTransientAllocator] Allocation failed: requested size = \(size), alignment = \(alignment), bufferOffset = \(bufferOffset), bufferSize = \(bufferSize)")
        }

        let begin = alignedOffset
        let end = alignedOffset + size
        let allocation = GpuTransientHeapBlock(buffer: buffer, begin: begin, end: end)
        bufferOffset = alignedOffset + size
        debugAllocated.append(allocation)

        return allocation
    }

    func clear() {
        bufferOffset = 0
        debugAllocated.removeAll()
    }
}
