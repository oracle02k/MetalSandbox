import Metal
import simd

final class PassthroughtTextureRenderCommandDispatcher: RenderCommandDispatcher {    
    struct Vertex {
        var position: simd_float3
        var texCoord: simd_float2
        
        static func makeVertexDescriptor() -> MTLVertexDescriptor {
            let vertexDescriptor = MTLVertexDescriptor()
            
            // position (simd_float3)
            vertexDescriptor.attributes[0].format = .float3
            vertexDescriptor.attributes[0].offset = 0
            vertexDescriptor.attributes[0].bufferIndex = BufferIndex.Vertices1.rawValue
            
            // texCoord (simd_float2)
            vertexDescriptor.attributes[1].format = .float2
            vertexDescriptor.attributes[1].offset = 0
            vertexDescriptor.attributes[1].bufferIndex = BufferIndex.Vertices2.rawValue
            
            // Vertex buffer layout
            vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride
            vertexDescriptor.layouts[0].stepFunction = .perVertex
            vertexDescriptor.layouts[1].stride = MemoryLayout<simd_float2>.stride
            vertexDescriptor.layouts[1].stepFunction = .perVertex
            
            return vertexDescriptor
        }
    }
    
    let encoder: MTLRenderCommandEncoder
    
    init(encoder: MTLRenderCommandEncoder) {
        self.encoder = encoder
    }

    func dispatch(_ renderable: PassthroughtTextureRenderable) {
        encoder.setVertexBuffer(renderable.positions.rawBuffer, offset: 0, index: BufferIndex.Vertices1.rawValue)
        encoder.setVertexBuffer(renderable.texCoords.rawBuffer, offset: 0, index: BufferIndex.Vertices2.rawValue)
        encoder.setFragmentTexture(renderable.source, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
}
