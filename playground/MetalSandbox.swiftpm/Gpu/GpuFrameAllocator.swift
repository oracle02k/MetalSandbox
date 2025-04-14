import Metal

/// メモリアロケーション情報
struct GpuFrameAllocation {
    let buffer: MTLBuffer
    let offset: Int
    let size: Int

    /// **単一の値を書き込む**
    func write<T>(value: T) {
        assert(MemoryLayout<T>.size <= size, "サイズオーバー")
        let pointer = buffer.contents().advanced(by: offset).assumingMemoryBound(to: T.self)
        pointer.pointee = value
    }

    /// **memcpyのように一括で配列を書き込む**
    func write<T>(from array: [T]) {
        let requiredSize = MemoryLayout<T>.stride * array.count
        assert(requiredSize <= size, "バッファサイズを超えています")

        // `UnsafeMutableRawPointer` に `memcpy` を適用
        _ = array.withUnsafeBytes { srcPointer in
            memcpy(buffer.contents().advanced(by: offset), srcPointer.baseAddress!, requiredSize)
        }
    }

    /// バッファのメモリをマッピングし、トレイリングクロージャを使って安全に操作する
    func withMappedPointer<T>(body: (UnsafeMutablePointer<T>) -> Void) {
        guard size >= MemoryLayout<T>.stride else {
            print("エラー: サイズが足りません")
            return
        }

        let pointer = buffer.contents().advanced(by: offset).assumingMemoryBound(to: T.self)
        body(pointer)
    }

    /// 配列データを書き込むバージョン
    func withMappedPointer<T>(body: (UnsafeMutablePointer<T>, Int) -> Void) {
        let count = size / MemoryLayout<T>.stride
        guard count > 0 else {
            print("エラー: サイズが無効")
            return
        }

        let pointer = buffer.contents().advanced(by: offset).assumingMemoryBound(to: T.self)
        body(pointer, count)
    }
}

/// フレームごとの一時的なデータを管理する Metal 向けアロケータ
class GpuFrameAllocator {
    private let gpu: GpuContext
    private let bufferCount: Int = 3  // トリプルバッファリング
    private var buffers = [MTLBuffer]()
    private var bufferSize: Int = 0
    private var currentBufferIndex: Int = 0
    private var currentOffset: Int = 0
    private var allocatedCount = 0
    private var allocated = [GpuFrameAllocation]()
    
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

    /// `size` バイトのメモリを確保し、バッファとオフセットを返す
    func allocate(size: Int, alignment: Int = 16/*MemoryLayout<Float>.alignment*/) -> GpuFrameAllocation? {
        let alignedOffset = (currentOffset + alignment - 1) & ~(alignment - 1)

        // バッファサイズを超えたら確保できない
        if alignedOffset + size > bufferSize {
            return nil
        }

        let allocation = GpuFrameAllocation(buffer: currentBuffer, offset: alignedOffset, size: size)
        currentOffset = alignedOffset + size
        allocatedCount += 1
        
        allocated.append(allocation)

        return allocation
    }

    /// フレームの切り替え時に呼び出す (次のバッファへ移動)
    func nextFrame() {
        currentBufferIndex = (currentBufferIndex + 1) % bufferCount
        currentOffset = 0
        allocatedCount = 0
        allocated.removeAll()
    }
}
