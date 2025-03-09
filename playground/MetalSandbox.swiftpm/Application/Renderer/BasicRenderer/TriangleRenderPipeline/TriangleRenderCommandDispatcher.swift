import Metal
import simd

final class TriangleRenderCommandDispatcher: RenderCommandDispatcher {
    struct Vertex {
        var position: simd_float3
        var color: simd_float4
    }
    
    let encoder: MTLRenderCommandEncoder
    var viewport = Viewport(leftTop: .init(0, 0), rightBottom: .init(320, 320))
    lazy var vertices: TypedBuffer<Vertex> = uninitialized()
    
    init(encoder: MTLRenderCommandEncoder) {
        self.encoder = encoder
    }
    
    func makeVerticies(gpu: GpuContext){
        vertices = gpu.makeTypedBuffer(elementCount: 3, options: []) as TypedBuffer<Vertex>
        vertices[0] = .init(position: .init(160, 0, 0.0), color: .init(1, 0, 0, 1))
        vertices[1] = .init(position: .init(0, 320, 0.0), color: .init(0, 1, 0, 1))
        vertices[2] = .init(position: .init(320, 320, 0.0), color: .init(0, 0, 1, 1))
    }
    
    func setViewport(_ viewport:Viewport){
        self.viewport = viewport
    }
    
    func dispatch() {
        withUnsafePointer(to: viewport) {
            encoder.setVertexBytes($0, length: MemoryLayout<Viewport>.stride, index: VertexInputIndex.Viewport.rawValue)
        }
        encoder.setVertexBuffer(vertices.rawBuffer, offset: 0, index: VertexInputIndex.Vertices1.rawValue)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
}
