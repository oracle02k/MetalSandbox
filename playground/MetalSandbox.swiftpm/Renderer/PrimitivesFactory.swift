import MetalKit

extension Primitives {
    class Factory {
        let device: MTLDevice

        init(_ device: MTLDevice) {
            self.device = device
        }

        func make(_ descriptor: Descriptor) -> Primitives {
            let buffers = descriptor.vertexBufferDescriptors.map { descriptor in
                descriptor.withUnsafeRawPointer {
                    device.makeBuffer(bytes: $0, length: descriptor.byteSize, options: [])!
                }
            }

            return Primitives(
                toporogy: descriptor.toporogy,
                vertexBuffers: buffers,
                vertexCount: descriptor.vertexCount
            )
        }
    }
}
