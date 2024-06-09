import MetalKit

protocol IndexBufferDescriptorProtocol {
    var indexType: MTLIndexType { get }
    var stride: Int { get }
    var count: Int { get }
    var byteSize: Int { get }
    
    func withUnsafeRawPointer<Result>(_ body: (UnsafeRawPointer) throws -> Result) rethrows -> Result
}

class IndexBufferU16Descriptor : IndexBufferDescriptorProtocol {
    var indexType: MTLIndexType { MTLIndexType.uint16 }
    var stride: Int { MemoryLayout<UInt16>.stride }
    var byteSize: Int { stride * count }
    var count: Int { content.count }
    lazy var content: [UInt16] = uninitialized()
    
    func withUnsafeRawPointer<Result>(
        _ body: (UnsafeRawPointer) throws -> Result
    ) rethrows -> Result {
        try content.withUnsafeBytes() { try body($0.baseAddress!) }
    }
}

class IndexBufferU32Descriptor : IndexBufferDescriptorProtocol {
    var indexType: MTLIndexType { MTLIndexType.uint32 }
    var stride: Int { MemoryLayout<UInt32>.stride }
    var byteSize: Int { stride * count }
    var count: Int { content.count }
    lazy var content: [UInt32] = uninitialized()
    
    func withUnsafeRawPointer<Result>(
        _ body: (UnsafeRawPointer) throws -> Result
    ) rethrows -> Result {
        try content.withUnsafeBytes() { try body($0.baseAddress!) }
    }
}


