import Metal

/// フレームごとの一時的なデータを管理する Metal 向けアロケータ
class GpuTransientAllocator {
    static let defaultAlignment = 16
    private let gpu: GpuContext
    private let bufferCount: Int = 3  // トリプルバッファリング
    private var buffers = [MTLBuffer]()
    private var bufferSize: Int = 0
    private var currentBufferIndex: Int = 0
    private var currentOffset: Int = 0
    private var debugAllocated = [GpuTransientHeapBlock]()

    init(gpu: GpuContext) {
        self.gpu = gpu
    }

    func build(size: Int) {
        self.bufferSize = size
        self.buffers = (0..<bufferCount).map { _ in
            gpu.makeBuffer(length: size, options: .storageModeShared)
        }
    }

    /// 現在のフレームのバッファを取得
    private var currentBuffer: MTLBuffer {
        return buffers[currentBufferIndex]
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
        return  GpuTypedTransientHeapBlock(raw: allocate(size: MemoryLayout<T>.stride * length)!)
    }
    
    /// `size` バイトのメモリを確保し、バッファとオフセットを返す
    func allocate(size: Int, alignment: Int = defaultAlignment ) -> GpuTransientHeapBlock? {
        let alignedOffset = (currentOffset + alignment - 1) & ~(alignment - 1)

        // バッファサイズを超えたら確保できない
        if alignedOffset + size > bufferSize {
            return nil
        }

        let begin = alignedOffset
        let end = alignedOffset + size
        let allocation = GpuTransientHeapBlock(buffer: currentBuffer, begin: begin, end: end)
        currentOffset = alignedOffset + size
        debugAllocated.append(allocation)
        
        return allocation
    }

    /// フレームの切り替え時に呼び出す (次のバッファへ移動)
    func nextFrame() {
        currentBufferIndex = (currentBufferIndex + 1) % bufferCount
        currentOffset = 0
        debugAllocated.removeAll()
    }
}
