import Metal
import simd

class TileRenderer {
    class Actor {
        let color: vector_float4
        let position: vector_float3
        let rotation: vector_float3
        let scale: vector_float3

        init(color: vector_float4, position: vector_float3, rotation: vector_float3, scale: vector_float3) {
            self.color = color
            self.position = position
            self.rotation = rotation
            self.scale = scale
        }
    }

    struct ActorParams {
        var modelMatrix: matrix_float4x4
        var color: vector_float4
    }

    struct Vertex {
        var position: vector_float4
    }

    struct CameraParams {
        var cameraPos: vector_float3
        var viewProjectionMatrix: matrix_float4x4
    }
    let BufferOffsetAlign = 16
    let MaxBuffersInFlight     = 3
    let MaxActor           = 32
    let ActorCountPerColumn    = 4
    let TransparentColumnCount = 4

    // To use an image block, you must balance the fragment shader's tile dimensions (`tileHeight` and `tileWidth`)
    // with the image block's memory size (`imageblockSampleLength`).
    //
    // A larger `tileWidth` and `tileHeight` may yield better performance because the GPU needs to switch
    // between fewer tiles to render the screen. However, a large tile size means that `imageblockSampleLength` must
    // be smaller.  The number of layers the image block structure supports affects the size
    // of `imageblockSampleLength`. More layers means you must decrease the fragment shader's tile size.
    // This chooses the values to which the renderer sets `tileHeight` and `tileWidth`.
    let optimalTileSize = MTLSizeMake(8, 8, 1)

    let quadVertices: [Vertex] = [
        .init(position: .init(1, 0, -1, 0)),
        .init(position: .init(-1, 0, -1, 0)),
        .init(position: .init(-1, 0, 1, 0)),

        .init(position: .init(1, 0, -1, 0)),
        .init(position: .init(-1, 0, 1, 0)),
        .init(position: .init(1, 0, 1, 0))
    ]

    var opaqueActors = [Actor]()
    var transparentActors = [Actor]()

    var projectionMatrix = matrix_float4x4()
    var rotation: Float = 0

    var supportsOrderIndependentTransparency = true
    var enableOrderIndependentTransparency = true
    var enableRotation = true

    var actorParams = [ActorParams]()
    var cameraParams = CameraParams(cameraPos: .zero, viewProjectionMatrix: .init())

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

    func build() {
        var genericColors: [vector_float4] = [
            .init(0.3, 0.9, 0.1, 1.0),
            .init(0.05, 0.5, 0.4, 1.0),
            .init(0.5, 0.05, 0.9, 1.0),
            .init(0.9, 0.1, 0.1, 1.0)
        ]

        var startPosition = vector_float3(7.0, 0.1, 12.0)
        let standardScale = vector_float3(1.5, 1.0, 1.5)
        let standardRotation = vector_float3(90.0, 0.0, 0.0)

        // Create opaque rotating quad actors at the rear of each column.
        for _ in 0..<ActorCountPerColumn {
            let actor = Actor(
                color: .init(0.5, 0.4, 0.3, 1.0),
                position: startPosition,
                rotation: standardRotation,
                scale: standardScale
            )

            opaqueActors.append(actor)
            startPosition[0] -= 4.5
        }

        // Create an opaque floor actor.
        do {
            let color = vector_float4(0.7, 0.7, 0.7, 1.0)
            let actor = Actor(color: color,
                              position: .init(0.0, -2.0, 6.0),
                              rotation: .init(0.0, 0.0, 0.0),
                              scale: .init(8.0, 1.0, 9.0))
            opaqueActors.append(actor)
        }

        startPosition = .init(7.0, 0.1, 0.0)
        var curPosition = startPosition

        // Create the transparent actors.
        for _ in 0..<TransparentColumnCount {
            for rowIndex in 0..<ActorCountPerColumn {
                genericColors[rowIndex][3] -= 0.2
                let actor = Actor(color: genericColors[rowIndex],
                                  position: curPosition,
                                  rotation: standardRotation,
                                  scale: standardScale)
                transparentActors.append(actor)
                curPosition[2] += 3.0
            }
            startPosition[0] -= 4.5
            curPosition = startPosition
        }
    }

    func changeSize(size: CGSize) {
        let aspect = Float(size.width / size.height)
        projectionMatrix = matrix_perspective_left_hand(radians_from_degrees(65.0), aspect, 1.0, 150.0)
    }

    func updateState() {
        actorParams.removeAll()
        for i in 0..<opaqueActors.count {
            let translationMatrix = matrix4x4_translation(opaqueActors[i].position)
            let scaleMatrix = matrix4x4_scale(opaqueActors[i].scale)
            let rotationXMatrix = matrix4x4_rotation(radians_from_degrees(opaqueActors[i].rotation.x), 1.0, 0.0, 0.0)
            var rotationMatrix = matrix_multiply(matrix4x4_rotation(radians_from_degrees(rotation), 0.0, 1.0, 0.0), rotationXMatrix)

            // Last opaque actor is tbe floor which has no rotation.
            if i == opaqueActors.count - 1 {
                rotationMatrix = matrix_identity_float4x4
            }

            let actorParam =  ActorParams(
                modelMatrix: matrix_multiply(translationMatrix, matrix_multiply(rotationMatrix, scaleMatrix)),
                color: opaqueActors[i].color
            )

            actorParams.append(actorParam)
        }

        for i in 0..<transparentActors.count {
            let translationMatrix = matrix4x4_translation(transparentActors[i].position)
            let scaleMatrix = matrix4x4_scale(transparentActors[i].scale)
            let rotationXMatrix = matrix4x4_rotation(radians_from_degrees(transparentActors[i].rotation.x), 1.0, 0.0, 0.0)
            let rotationMatrix = matrix_multiply(matrix4x4_rotation(radians_from_degrees(rotation), 0.0, 1.0, 0.0), rotationXMatrix)

            let actorParam =  ActorParams(
                modelMatrix: matrix_multiply(translationMatrix, matrix_multiply(rotationMatrix, scaleMatrix)),
                color: transparentActors[i].color
            )

            actorParams.append(actorParam)
        }

        let eyePos = vector_float3(0.0, 2.0, -12.0)
        let eyeTarget = vector_float3(eyePos.x, eyePos.y - 0.25, eyePos.z + 1.0)
        let eyeUp = vector_float3(0.0, 1.0, 0.0)
        let viewMatrix = matrix_look_at_left_hand(eyePos, eyeTarget, eyeUp)

        cameraParams = .init(
            cameraPos: eyePos,
            viewProjectionMatrix: matrix_multiply(projectionMatrix, viewMatrix)
        )

        if enableRotation {
            rotation += 1.0
        }
    }

    func draw(_ renderCommandBuilder: RenderCommandBuilder) {
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
                builder.setFragmentBuffer(actorParams, index: 2)
            }

            builder.withDebugGroup("Opaque Actor Rendering") {
                builder.withRenderPipelineState { d in
                    d.label = "Unordered alpha blending pipeline"
                    d.vertexFunction = builder.findFunction(by: .TileForwardVS)
                    d.fragmentFunction = builder.findFunction(by: .TileOpaqueFS)

                    d.colorAttachments[0].pixelFormat = .bgra8Unorm
                    d.depthAttachmentPixelFormat = .depth32Float
                    d.stencilAttachmentPixelFormat = .invalid

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
                for index in 0..<opaqueActors.count {
                    builder.setVertexBuffer(actorParams[index], index: 2)
                    builder.setFragmentBuffer(actorParams[index], index: 2)
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
                    d.colorAttachments[0].pixelFormat = .bgra8Unorm
                    d.depthAttachmentPixelFormat = .depth32Float
                    d.stencilAttachmentPixelFormat = .invalid
                }

                builder.setCullMode(.none)
                for i in 0..<transparentActors.count {
                    let index = i + opaqueActors.count
                    builder.setVertexBuffer(actorParams[index], index: 2)
                    builder.setFragmentBuffer(actorParams[index], index: 2)
                    builder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                }
            }

            builder.withDebugGroup("Blend Fragments") {
                builder.withRenderPipelineState { d in
                    d.label = "Transparent Fragment Blending"
                    d.vertexFunction = builder.findFunction(by: .TileQuadPassVS)
                    d.fragmentFunction = builder.findFunction(by: .TileBlendFS)
                    d.colorAttachments[0].pixelFormat = .bgra8Unorm
                    d.depthAttachmentPixelFormat = .depth32Float
                    d.stencilAttachmentPixelFormat = .invalid
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
