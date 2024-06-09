typealias float2 = SIMD2<Float>
typealias float3 = SIMD3<Float>
typealias float4 = SIMD4<Float>

protocol VertexBufferDescriptorProtocol {
    var stride: Int { get }
    var count: Int { get }
    var byteSize: Int { get }

    func withUnsafeRawPointer<Result>(_ body: (UnsafeRawPointer) throws -> Result) rethrows -> Result
}    

class VertexBufferDescriptor<T> : VertexBufferDescriptorProtocol {
    typealias VertexLayout = T
    var stride: Int { MemoryLayout<VertexLayout>.stride }
    var byteSize: Int { stride * count }
    var count: Int { content.count }
    lazy var content: [T] = uninitialized()
    
    func withUnsafeRawPointer<Result>(
        _ body: (UnsafeRawPointer) throws -> Result
    ) rethrows -> Result {
        try content.withUnsafeBytes() { try body($0.baseAddress!) }
    }
}
