import MetalKit

extension MTLRenderCommandEncoder {
    func drawMesh(_ mesh: Primitives) {
        mesh.vertexBuffers.enumerated().forEach { index, buffer in
            self.setVertexBuffer(buffer, offset: 0, index: index)
        }
        self.drawPrimitives(type: mesh.toporogy, vertexStart: 0, vertexCount: mesh.vertexCount)
    }

    func drawIndexedMesh(_ mesh: IndexedPrimitives) {
        mesh.vertexBuffers.enumerated().forEach { index, buffer in
            self.setVertexBuffer(buffer, offset: 0, index: index)
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
