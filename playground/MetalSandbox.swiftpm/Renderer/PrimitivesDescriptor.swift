import MetalKit

class PrimitiveDescriptor {
    lazy var vertexBufferDescriptors: [VertexBufferDescriptorProtocol] = uninitialized()
    lazy var toporogy: MTLPrimitiveType = uninitialized()
    lazy var vertexCount: Int  = uninitialized()
}
