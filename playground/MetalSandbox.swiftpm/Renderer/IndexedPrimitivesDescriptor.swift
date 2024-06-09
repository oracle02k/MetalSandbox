import MetalKit

class IndexedPrimitiveDescriptor {
    lazy var vertexBufferDescriptors: [VertexBufferDescriptorProtocol] = uninitialized()
    lazy var indexBufferDescriptor: IndexBufferDescriptorProtocol = uninitialized()
    lazy var toporogy: MTLPrimitiveType = uninitialized()
}
