import MetalKit

extension IndexedMesh {
    class Factory {
        let gpu: GpuContext

        init(gpu: GpuContext) {
            self.gpu = gpu
        }

        func make(_ descriptor: IndexedMesh.Descriptor) -> IndexedMesh {
            let vertexBuffers = descriptor.vertexBufferDescriptors.map { descriptor in
                descriptor.withUnsafeRawPointer {
                    gpu.device.makeBuffer(bytes: $0, length: descriptor.byteSize, options: [])!
                }
            }

            let indexBufferDescriptor = descriptor.indexBufferDescriptor
            let indexBuffer = indexBufferDescriptor.withUnsafeRawPointer {
                gpu.device.makeBuffer(bytes: $0, length: indexBufferDescriptor.byteSize, options: [])!
            }

            return IndexedMesh(
                toporogy: descriptor.toporogy,
                vertexBuffers: vertexBuffers,
                indexBuffer: indexBuffer,
                indexType: indexBufferDescriptor.indexType,
                indexCount: indexBufferDescriptor.count
            )
        }
    }
}
