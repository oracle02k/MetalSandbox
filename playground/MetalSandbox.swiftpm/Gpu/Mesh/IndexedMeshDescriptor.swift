import MetalKit

extension IndexedMesh {
    class Descriptor {
        lazy var vertexBufferDescriptors: [VertexBufferDescriptorProtocol] = uninitialized()
        lazy var indexBufferDescriptor: IndexBufferDescriptorProtocol = uninitialized()
        lazy var toporogy: MTLPrimitiveType = uninitialized()
    }
}
