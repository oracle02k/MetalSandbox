import Foundation

class AlignedBuffer<T> {
    let count: Int
    let align: size_t
    let stride: size_t
    var byteSize: size_t { stride * count }
    lazy var pointer: UnsafeMutableRawPointer = uninitialized()

    init(count: Int, align: Int? = nil) {
        self.align = align ?? alignof(T.self)
        self.stride = AppModule.align(sizeof(T.self), self.align)
        self.count = count
    }

    func bind(pointer: UnsafeMutableRawPointer) {
        self.pointer = pointer
    }

    func read(_ index: Int) -> T {
        return pointer.load(fromByteOffset: index * stride, as: T.self)
    }

    func write(_ index: Int, value: T) {
        pointer.storeBytes(of: value, toByteOffset: index * stride, as: T.self)
    }

    var contents: T {
        get { read(0) }
        set { write(0, value: newValue) }
    }

    subscript(index: Int) -> T {
        get { read(index) }
        set { write(index, value: newValue) }
    }
}
