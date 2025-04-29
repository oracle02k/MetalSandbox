import Metal

struct GpuBufferBinding: Equatable {
    let buffer: MTLBuffer
    let offset: Int

    static func == (lhs: GpuBufferBinding, rhs: GpuBufferBinding) -> Bool {
        return  lhs.buffer === rhs.buffer &&
            lhs.offset == rhs.offset
    }
}
