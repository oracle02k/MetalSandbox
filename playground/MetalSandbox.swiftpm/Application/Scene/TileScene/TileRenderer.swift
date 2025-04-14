import Metal
import simd

class TileRenderer {
    // To use an image block, you must balance the fragment shader's tile dimensions (`tileHeight` and `tileWidth`)
    // with the image block's memory size (`imageblockSampleLength`).
    //
    // A larger `tileWidth` and `tileHeight` may yield better performance because the GPU needs to switch
    // between fewer tiles to render the screen. However, a large tile size means that `imageblockSampleLength` must
    // be smaller.  The number of layers the image block structure supports affects the size
    // of `imageblockSampleLength`. More layers means you must decrease the fragment shader's tile size.
    // This chooses the values to which the renderer sets `tileHeight` and `tileWidth`.
    // let optimalTileSize = MTLSizeMake(8, 8, 1)
    
    struct Vertex {
        var position: vector_float4
    }
    
    let quadVertices: [Vertex] = [
        .init(position: .init(1, 0, -1, 0)),
        .init(position: .init(-1, 0, -1, 0)),
        .init(position: .init(-1, 0, 1, 0)),
        .init(position: .init(1, 0, -1, 0)),
        .init(position: .init(-1, 0, 1, 0)),
        .init(position: .init(1, 0, 1, 0))
    ]
    
    func draw(
        _ renderCommandBuilder: RenderCommandBuilder,
        opaqueActorParams: [TileActorParams],
        transparentActorParams: [TileActorParams],
        cameraParams: TileCameraParams
    ) {
        renderCommandBuilder.withStateScope { builder in
            // Configure the kernel tile shader to initialize the image block for each frame.
            builder.withDebugGroup("Init Image Block") {
                builder.withTileRenderState { d in
                    d.label = "Init Image Block Kernel"
                    d.tileFunction = builder.findFunction(by: .TileInitTransparentFragmentStore)
                    d.threadgroupSizeMatchesTileSize = true
                }
                builder.dispatchThreadsPerTile()
            }
            
            builder.withDebugGroup("Common Buffer Binding") {
                builder.setVertexBuffer(quadVertices, index: 1)
                builder.setVertexBuffer(cameraParams, index: 3)
            }
            
            builder.withDebugGroup("Opaque Actor Rendering") {
                builder.withRenderPipelineState { d in
                    d.label = "Unordered alpha blending pipeline"
                    d.vertexFunction = builder.findFunction(by: .TileForwardVS)
                    d.fragmentFunction = builder.findFunction(by: .TileOpaqueFS)
                    d.colorAttachments[0].isBlendingEnabled = true
                    d.colorAttachments[0].alphaBlendOperation = .add
                    d.colorAttachments[0].sourceAlphaBlendFactor = .one
                    d.colorAttachments[0].destinationAlphaBlendFactor = .zero
                    d.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                    d.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                    d.colorAttachments[0].rgbBlendOperation = .add
                    d.colorAttachments[0].writeMask = .all
                }
                
                builder.withDepthStencilState { d in
                    d.label = "DepthCompareLessEqualAndNoWrite"
                    d.isDepthWriteEnabled = false
                    d.depthCompareFunction = .lessEqual
                    d.backFaceStencil = nil
                    d.frontFaceStencil = nil
                }
                
                builder.setCullMode(.none)
                for actor in opaqueActorParams {
                    builder.setVertexBuffer(actor, index: 2)
                    builder.setFragmentBuffer(actor, index: 2)
                    builder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                }
            }
            
            builder.withDebugGroup("Transparent Actor Rendering") {
                builder.withRenderPipelineState { d in
                    d.label = "Transparent Fragment Store Op"
                    d.vertexFunction = builder.findFunction(by: .TileForwardVS)
                    d.fragmentFunction = builder.findFunction(by: .TileProcessTransparentFS)
                    d.colorAttachments[0].isBlendingEnabled = false
                    
                    // Disable the color write mask.
                    // This fragment shader only writes color data into the image block.
                    // It doesn't produce an output for the color attachment.
                    d.colorAttachments[0].writeMask = []
                }
                
                builder.setCullMode(.none)
                for actor in transparentActorParams {
                    builder.setVertexBuffer(actor, index: 2)
                    builder.setFragmentBuffer(actor, index: 2)
                    builder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                }
            }
            
            builder.withDebugGroup("Blend Fragments") {
                builder.withRenderPipelineState { d in
                    d.label = "Transparent Fragment Blending"
                    d.vertexFunction = builder.findFunction(by: .TileQuadPassVS)
                    d.fragmentFunction = builder.findFunction(by: .TileBlendFS)
                    d.vertexDescriptor = nil
                }
                
                builder.withDepthStencilState { d in
                    d.label = "DepthCompareAlwaysAndNoWrite"
                    d.isDepthWriteEnabled = false
                    d.depthCompareFunction = .always
                    d.backFaceStencil = nil
                    d.frontFaceStencil = nil
                }
                
                builder.setCullMode(.none)
                builder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            }
        }
    }
}
