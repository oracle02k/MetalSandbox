import Metal
import simd

class TriangleRenderer{
    struct Vertex {
        let position: simd_float3
        let color: simd_float4
    }
    
    typealias CommandBuilder = RenderCommandBuilder
    let renderCommandBuilder: CommandBuilder
    
    @Cached private var vertexDescriptor = {
        let descriptor = MTLVertexDescriptor()
        
        // Position (simd_float3)
        descriptor.attributes[0].format = .float3
        descriptor.attributes[0].offset = 0
        descriptor.attributes[0].bufferIndex = BufferIndex.Vertices1.rawValue
        
        // Color (simd_float4)
        descriptor.attributes[1].format = .float4
        descriptor.attributes[1].offset = 0
        descriptor.attributes[1].bufferIndex = BufferIndex.Vertices2.rawValue
        
        // Vertex buffer layout
        descriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride
        descriptor.layouts[0].stepFunction = .perVertex
        descriptor.layouts[1].stride = MemoryLayout<simd_float4>.stride
        descriptor.layouts[1].stepFunction = .perVertex
        
        return descriptor
    }()
    
    init(renderCommandBuilder: CommandBuilder){
        self.renderCommandBuilder = renderCommandBuilder
    }
    
    func draw(vertices: [Vertex]) {
        let positions = vertices.map{ $0.position }
        let colors = vertices.map { $0.color }
        let viewport = Viewport(leftTop: .init(0, 0), rightBottom: .init(320, 320))
        
        renderCommandBuilder.withStateScope{ builder in
            builder.withRenderPipelineState{ d in
                d.vertexDescriptor = vertexDescriptor
                d.vertexFunction = builder.findFunction(by: .VertexShader)
                d.fragmentFunction = builder.findFunction(by: .FragmentShader)
            }
            builder.setVertexBuffer(viewport, index: BufferIndex.Viewport)
            builder.setVertexBuffer(positions, index: BufferIndex.Vertices1)
            builder.setVertexBuffer(colors, index: BufferIndex.Vertices2)
            builder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        }
    }
}
