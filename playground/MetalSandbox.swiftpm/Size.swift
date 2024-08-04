import Foundation

func sizeof<T>(_ type: T.Type) -> size_t {
    return MemoryLayout<T>.stride
}

func alignof<T>(_ type: T.Type) -> size_t {
    return MemoryLayout<T>.alignment
}

/// Aligns a value to an address.
func align (_ value: size_t, _ align: size_t) -> size_t {
    if align == 0 {
        return value
    } else if (value & (align-1)) == 0 {
        return value
    } else {
        return (value+align) & ~(align-1)
    }
}
