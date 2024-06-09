import MetalKit

class IndexedPrimitives
{
    let toporogy: MTLPrimitiveType
    let vertexBuffers: [MTLBuffer]
    let indexBuffer: MTLBuffer
    let indexType: MTLIndexType
    let indexCount: Int
    
    init(
        toporogy: MTLPrimitiveType, 
        vertexBuffers: [MTLBuffer], 
        indexBuffer: MTLBuffer, 
        indexType: MTLIndexType, 
        indexCount: Int
    ) {
        self.toporogy = toporogy
        self.vertexBuffers = vertexBuffers
        self.indexBuffer = indexBuffer
        self.indexType = indexType
        self.indexCount = indexCount
    }
}
