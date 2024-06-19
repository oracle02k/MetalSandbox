import MetalKit

extension IndexedPrimitives {
    class Factory {
        let device: MTLDevice

        init(_ device: MTLDevice) {
            self.device = device
        }

        func make(_ descriptor: IndexedPrimitives.Descriptor) -> IndexedPrimitives {
            let vertexBuffers = descriptor.vertexBufferDescriptors.map { descriptor in
                descriptor.withUnsafeRawPointer {
                    device.makeBuffer(bytes: $0, length: descriptor.byteSize, options: [])!
                }
            }

            let indexBufferDescriptor = descriptor.indexBufferDescriptor
            let indexBuffer = indexBufferDescriptor.withUnsafeRawPointer {
                device.makeBuffer(bytes: $0, length: indexBufferDescriptor.byteSize, options: [])!
            }

            return IndexedPrimitives(
                toporogy: descriptor.toporogy,
                vertexBuffers: vertexBuffers,
                indexBuffer: indexBuffer,
                indexType: indexBufferDescriptor.indexType,
                indexCount: indexBufferDescriptor.count
            )
        }
    }
}
