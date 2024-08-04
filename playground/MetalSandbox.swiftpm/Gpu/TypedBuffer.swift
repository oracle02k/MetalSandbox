import MetalKit

class TypedBuffer<T> {
    var count: Int {alignedBuffer.count}
    var align: size_t {alignedBuffer.align}
    var stride: size_t {alignedBuffer.stride}
    var byteSize: size_t { alignedBuffer.byteSize }
    lazy var rawBuffer: MTLBuffer = uninitialized()
    private let alignedBuffer: AlignedBuffer<T>

    init (_ alignedBuffer: AlignedBuffer<T>) {
        self.alignedBuffer = alignedBuffer
    }

    func bind(_ buffer: MTLBuffer) {
        rawBuffer = buffer
        alignedBuffer.bind(pointer: rawBuffer.contents())
    }

    func read(_ index: Int) -> T {
        return alignedBuffer.read(index)
    }

    func write(_ index: Int, value: T) {
        alignedBuffer.write(index, value: value)
    }

    var contents: T {
        get { alignedBuffer.read(0) }
        set { alignedBuffer.write(0, value: newValue) }
    }

    subscript(index: Int) -> T {
        get { alignedBuffer.read(index) }
        set { alignedBuffer.write(index, value: newValue) }
    }
}
