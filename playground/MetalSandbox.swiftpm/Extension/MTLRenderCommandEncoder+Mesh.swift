import MetalKit

extension MTLRenderCommandEncoder {
    func drawMesh(_ mesh: Mesh) {
        mesh.vertexBuffers.enumerated().forEach { index, buffer in
            self.setVertexBuffer(buffer, offset: 0, index: BufferIndex.Vertices1.rawValue + index)
        }
        self.drawPrimitives(type: mesh.toporogy, vertexStart: 0, vertexCount: mesh.vertexCount)
    }

    func drawIndexedMesh(_ mesh: IndexedMesh) {
        mesh.vertexBuffers.enumerated().forEach { index, buffer in
            self.setVertexBuffer(buffer, offset: 0, index: BufferIndex.Vertices1.rawValue + index)
        }
        self.drawIndexedPrimitives(
            type: mesh.toporogy,
            indexCount: mesh.indexCount,
            indexType: mesh.indexType,
            indexBuffer: mesh.indexBuffer,
            indexBufferOffset: 0
        )
    }
}
