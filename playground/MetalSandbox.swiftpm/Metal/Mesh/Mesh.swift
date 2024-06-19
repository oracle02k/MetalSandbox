import MetalKit

class Mesh {
    let toporogy: MTLPrimitiveType
    let vertexBuffers: [MTLBuffer]
    let vertexCount: Int

    init(toporogy: MTLPrimitiveType, vertexBuffers: [MTLBuffer], vertexCount: Int) {
        self.toporogy = toporogy
        self.vertexBuffers = vertexBuffers
        self.vertexCount = vertexCount
    }
}
