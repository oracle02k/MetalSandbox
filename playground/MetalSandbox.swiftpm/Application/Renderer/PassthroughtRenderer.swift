import Metal
import simd

class PassthroughtRenderer {
    let renderCommandBuilder: RenderCommandBuilder

    init(renderCommandBuilder: RenderCommandBuilder) {
        self.renderCommandBuilder = renderCommandBuilder
    }

    let positions: [simd_float3] = [
        .init(-1, 1, 0.0),
        .init(-1, -1, 0.0),
        .init(1, 1, 0.0),
        .init(1, 1, 0.0),
        .init(-1, -1, 0.0),
        .init(1, -1, 0.0)
    ]

    let texCoords: [simd_float2] = [
        .init(0, 0), // 左上
        .init(0, 1), // 左下
        .init(1, 0), // 右上
        .init(1, 0), // 右上
        .init(0, 1), // 左下
        .init(1, 1) // 右下
    ]

    @Cached private var vertexDescriptor = {
        let descriptor = MTLVertexDescriptor()

        // Position (simd_float3)
        descriptor.attributes[0].format = .float3
        descriptor.attributes[0].offset = 0
        descriptor.attributes[0].bufferIndex = BufferIndex.Vertices1.rawValue

        // Color (simd_float4)
        descriptor.attributes[1].format = .float2
        descriptor.attributes[1].offset = 0// MemoryLayout<simd_float3>.stride
        descriptor.attributes[1].bufferIndex = BufferIndex.Vertices2.rawValue

        // Vertex buffer layout
        descriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride
        descriptor.layouts[0].stepFunction = .perVertex
        descriptor.layouts[1].stride = MemoryLayout<simd_float2>.stride
        descriptor.layouts[1].stepFunction = .perVertex

        return descriptor
    }()

    func draw(_ texture: MTLTexture) {
        renderCommandBuilder.withStateScope { builder in
            builder.withRenderPipelineState { d in
                d.vertexDescriptor = vertexDescriptor
                d.vertexFunction = builder.findFunction(by: .PassthroughtTextureVS)
                d.fragmentFunction = builder.findFunction(by: .PassthroughtTextureFS)
            }
            builder.setVertexBuffer(positions, index: BufferIndex.Vertices1)
            builder.setVertexBuffer(texCoords, index: BufferIndex.Vertices2)
            builder.setFragmentTexture(texture, index: 0)
            builder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }
    }
}
