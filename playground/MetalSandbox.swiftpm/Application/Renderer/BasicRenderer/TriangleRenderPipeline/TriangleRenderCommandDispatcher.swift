import Metal
import simd

final class TriangleRenderCommandDispatcher: RenderCommandDispatcher {    
    struct Vertex {
        var position: simd_float3
        var color: simd_float4
        
     static func makeVertexDescriptor() -> MTLVertexDescriptor {
            let vertexDescriptor = MTLVertexDescriptor()
            
            // Position (simd_float3)
            vertexDescriptor.attributes[0].format = .float3
            vertexDescriptor.attributes[0].offset = 0
            vertexDescriptor.attributes[0].bufferIndex = BufferIndex.Vertices1.rawValue
            
            // Color (simd_float4)
            vertexDescriptor.attributes[1].format = .float4
            vertexDescriptor.attributes[1].offset = 0//MemoryLayout<simd_float3>.stride
            vertexDescriptor.attributes[1].bufferIndex = BufferIndex.Vertices2.rawValue
            
            // Vertex buffer layout
            vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride
            vertexDescriptor.layouts[0].stepFunction = .perVertex
            vertexDescriptor.layouts[1].stride = MemoryLayout<simd_float4>.stride
            vertexDescriptor.layouts[1].stepFunction = .perVertex
            
            return vertexDescriptor
        }
    }
    
    let encoder: MTLRenderCommandEncoder
    var viewport = Viewport(leftTop: .init(0, 0), rightBottom: .init(320, 320))

    init(encoder: MTLRenderCommandEncoder) {
        self.encoder = encoder
    }
    
    func dispatch(_ renderable: TriangleRenderable) {
        withUnsafePointer(to: viewport) {
            encoder.setVertexBytes($0, length: MemoryLayout<Viewport>.stride, index: BufferIndex.Viewport.rawValue)
        }
        encoder.setVertexBuffer(renderable.positions.rawBuffer, offset: 0, index: BufferIndex.Vertices1.rawValue)
        encoder.setVertexBuffer(renderable.colors.rawBuffer, offset: 0, index: BufferIndex.Vertices2.rawValue)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3 * renderable.triangleCount)
    }
}
