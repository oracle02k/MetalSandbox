/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 The renderer class that sets up Metal and draws each frame.
 */
import MetalKit

class TileRenderPass {
    enum BufferIndices: Int {
        case Vertices         = 1
        case ActorParams      = 2
        case CameraParams     = 3
    }

    // RenderTarget index values shared between the shader and C code to ensure that the Metal shader render target
    // index matches the Metal API pipeline and render pass.
    enum RenderTargetIndices: Int {
        case Color           = 0
    }

    // Structures shared between the shader and C code to ensure that the layout of per frame data
    // accessed in Metal shaders matches the layout of the data set in C code.
    // Data constant across all threads, vertices, and fragments.
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

    // `[MTLRenderCommandEncoder setVertexBuffer:offset:atIndex]` requires that buffer offsets be
    // 256 bytes aligned for buffers using the constant address space and 16 bytes aligned for buffers
    // using the device address space. The sample uses the device address space for the `actorParams`
    // parameter of the shaders and uses the `set[Vertex|Framgment:offset:` methods to iterate
    // through `ActorParams` structures. So it aligns each element of `_actorParamsBuffers` by 16 bytes.
    let BufferOffsetAlign = 16
    let MaxBuffersInFlight     = 3
    let MaxActor           = 32
    let ActorCountPerColumn    = 4
    let TransparentColumnCount = 4

    lazy var lessEqualDepthStencilState: MTLDepthStencilState = uninitialized()
    lazy var noWriteLessEqualDepthStencilState: MTLDepthStencilState = uninitialized()
    lazy var noDepthStencilState: MTLDepthStencilState = uninitialized()

    lazy var opaquePipeline: MTLRenderPipelineState = uninitialized()
    lazy var initImageBlockPipeline: MTLRenderPipelineState = uninitialized()
    lazy var transparencyPipeline: MTLRenderPipelineState = uninitialized()
    lazy var blendPipelineState: MTLRenderPipelineState = uninitialized()

    lazy var forwardRenderPassDescriptor: MTLRenderPassDescriptor = uninitialized()
    lazy var counterSampleBuffer: MTLCounterSampleBuffer? = uninitialized()

    var actorParamsBuffers = [TypedBuffer<ActorParams>]()
    var cameraParamsBuffers = [TypedBuffer<CameraParams>]()

    lazy var actorMesh: MTLBuffer = uninitialized()

    var opaqueActors = [Actor]()
    var transparentActors = [Actor]()

    var optimalTileSize = MTLSize()
    var projectionMatrix = matrix_float4x4()
    var rotation: Float = 0

    var supportsOrderIndependentTransparency = true
    var enableOrderIndependentTransparency = true
    var enableRotation = false

    var gpu: GpuContext

    init(with gpu: GpuContext) {
        self.gpu = gpu
    }

    func build(maxFramesInFlight: Int) {
        loadResources(maxFramesInFlight: maxFramesInFlight)
        loadMetal()
    }

    /// Initializes the app's starting values, and creates actors and constant buffers.
    func loadResources(maxFramesInFlight: Int) {
        enableOrderIndependentTransparency = true
        rotation = 0
        enableRotation = true

        // To use an image block, you must balance the fragment shader's tile dimensions (`tileHeight` and `tileWidth`)
        // with the image block's memory size (`imageblockSampleLength`).
        //
        // A larger `tileWidth` and `tileHeight` may yield better performance because the GPU needs to switch
        // between fewer tiles to render the screen. However, a large tile size means that `imageblockSampleLength` must
        // be smaller.  The number of layers the image block structure supports affects the size
        // of `imageblockSampleLength`. More layers means you must decrease the fragment shader's tile size.
        // This chooses the values to which the renderer sets `tileHeight` and `tileWidth`.
        optimalTileSize = MTLSizeMake(32, 16, 1)

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

        // Create the constant buffers for each frame.
        for i in 0..<maxFramesInFlight {
            // let actorParamsBuffer = gpu.makeBuffer(length: Align(sizeof(ActorParams.self),BufferOffsetAlign),
            // options: .storageModeShared)
            let actorParamsBuffer = gpu.makeTypedBuffer(elementCount: MaxActor, align: BufferOffsetAlign, options: .storageModeShared) as TypedBuffer<ActorParams>
            actorParamsBuffer.rawBuffer.label = "actor params[\(i)]"
            actorParamsBuffers.append(actorParamsBuffer)

            let cameraParamsBuffer = gpu.makeTypedBuffer(options: .storageModeShared) as TypedBuffer<CameraParams>
            cameraParamsBuffer.rawBuffer.label = "camera params[\(i)]"
            cameraParamsBuffers.append(cameraParamsBuffer)
        }
    }

    /// Creates the Metal render state objects.
    func loadMetal() {
        // Check that this GPU supports raster order groups.
        supportsOrderIndependentTransparency = gpu.device.supportsFamily(.apple4)
        Logger.log("Selected Device \(gpu.device.name)")

        do {
            let vertexFunc = gpu.findFunction(by: .TileRendererFowardVertext)
            let fragmentFunc = gpu.findFunction(by: .TileRendererOpaqueFragment)

            let renderPipelineDesc = MTLRenderPipelineDescriptor()
            renderPipelineDesc.label = "Unordered alpha blending pipeline"
            renderPipelineDesc.vertexFunction = vertexFunc
            renderPipelineDesc.fragmentFunction = fragmentFunc
            renderPipelineDesc.colorAttachments[RenderTargetIndices.Color.rawValue].pixelFormat = .bgra8Unorm
            renderPipelineDesc.depthAttachmentPixelFormat = .depth32Float
            renderPipelineDesc.stencilAttachmentPixelFormat = .invalid

            renderPipelineDesc.colorAttachments[RenderTargetIndices.Color.rawValue].isBlendingEnabled = true
            renderPipelineDesc.colorAttachments[RenderTargetIndices.Color.rawValue].alphaBlendOperation = .add
            renderPipelineDesc.colorAttachments[RenderTargetIndices.Color.rawValue].sourceAlphaBlendFactor = .one
            renderPipelineDesc.colorAttachments[RenderTargetIndices.Color.rawValue].destinationAlphaBlendFactor = .zero
            renderPipelineDesc.colorAttachments[RenderTargetIndices.Color.rawValue].sourceRGBBlendFactor = .sourceAlpha
            renderPipelineDesc.colorAttachments[RenderTargetIndices.Color.rawValue].destinationRGBBlendFactor = .oneMinusSourceAlpha
            renderPipelineDesc.colorAttachments[RenderTargetIndices.Color.rawValue].rgbBlendOperation = .add
            renderPipelineDesc.colorAttachments[RenderTargetIndices.Color.rawValue].writeMask = .all

            opaquePipeline = gpu.makeRenderPipelineState(renderPipelineDesc)
        }

        // Only use transparency effects if the device supports tiles shaders and image blocks.
        if supportsOrderIndependentTransparency {
            enableOrderIndependentTransparency = true

            // Set up the transparency pipeline so that it populates the image block with fragment values.
            do {
                let vertexFunction = gpu.findFunction(by: .TileRendererFowardVertext)
                let fragmentFunction = gpu.findFunction(by: .TileRendererTransparentFragment)

                let renderPipelineDesc = MTLRenderPipelineDescriptor()
                renderPipelineDesc.label = "Transparent Fragment Store Op"
                renderPipelineDesc.vertexFunction = vertexFunction
                renderPipelineDesc.fragmentFunction = fragmentFunction
                renderPipelineDesc.colorAttachments[RenderTargetIndices.Color.rawValue].isBlendingEnabled = false

                // Disable the color write mask.
                // This fragment shader only writes color data into the image block.
                // It doesn't produce an output for the color attachment.
                renderPipelineDesc.colorAttachments[RenderTargetIndices.Color.rawValue].writeMask = []
                renderPipelineDesc.colorAttachments[RenderTargetIndices.Color.rawValue].pixelFormat = .bgra8Unorm
                renderPipelineDesc.depthAttachmentPixelFormat = .depth32Float
                renderPipelineDesc.stencilAttachmentPixelFormat = .invalid

                transparencyPipeline = gpu.makeRenderPipelineState(renderPipelineDesc)
            }
            // Configure the kernel tile shader to initialize the image block for each frame.
            do {
                let kernelTileFunction = gpu.findFunction(by: .TileRendererInitTransparentFragmentStore)
                let tileDesc = MTLTileRenderPipelineDescriptor()
                tileDesc.label = "Init Image Block Kernel"
                tileDesc.tileFunction = kernelTileFunction
                tileDesc.colorAttachments[RenderTargetIndices.Color.rawValue].pixelFormat = .bgra8Unorm
                tileDesc.threadgroupSizeMatchesTileSize = true

                initImageBlockPipeline = try! gpu.device.makeRenderPipelineState(tileDescriptor: tileDesc, options: [], reflection: nil)
            }
            // Configure the pipeline to blend transparent and opaque fragments.
            do {
                let vertexFunction = gpu.findFunction(by: .TileRendererQuadPassVertex)
                let fragmentFunction = gpu.findFunction(by: .TileRendererBlendFragments)
                let renderPipelineDesc = MTLRenderPipelineDescriptor()
                renderPipelineDesc.label = "Transparent Fragment Blending"
                renderPipelineDesc.vertexFunction = vertexFunction
                renderPipelineDesc.fragmentFunction = fragmentFunction
                renderPipelineDesc.colorAttachments[RenderTargetIndices.Color.rawValue].pixelFormat = .bgra8Unorm
                renderPipelineDesc.depthAttachmentPixelFormat = .depth32Float
                renderPipelineDesc.stencilAttachmentPixelFormat = .invalid
                renderPipelineDesc.vertexDescriptor = nil

                blendPipelineState = gpu.makeRenderPipelineState(renderPipelineDesc)
            }
        } else {
            enableOrderIndependentTransparency = false
        }

        do {
            let depthStencilDesc = MTLDepthStencilDescriptor()
            depthStencilDesc.label = "DepthCompareAlwaysAndNoWrite"
            depthStencilDesc.isDepthWriteEnabled = false
            depthStencilDesc.depthCompareFunction = .always
            depthStencilDesc.backFaceStencil = nil
            depthStencilDesc.frontFaceStencil = nil
            noDepthStencilState = gpu.makeDepthStancilState(depthStencilDesc)

            depthStencilDesc.label = "DepthCompareLessEqualAndWrite"
            depthStencilDesc.isDepthWriteEnabled = true
            depthStencilDesc.depthCompareFunction = .lessEqual
            lessEqualDepthStencilState = gpu.makeDepthStancilState(depthStencilDesc)

            depthStencilDesc.label = "DepthCompareLessEqualAndNoWrite"
            depthStencilDesc.isDepthWriteEnabled = false
            noWriteLessEqualDepthStencilState = gpu.makeDepthStancilState(depthStencilDesc)
        }

        forwardRenderPassDescriptor = MTLRenderPassDescriptor()
        counterSampleBuffer = gpu.attachCounterSample(
            to: forwardRenderPassDescriptor, 
            index: RenderTargetIndices.Color.rawValue
        )

        if supportsOrderIndependentTransparency {
            // Set the tile size for the fragment shader.
            forwardRenderPassDescriptor.tileWidth  = optimalTileSize.width
            forwardRenderPassDescriptor.tileHeight = optimalTileSize.height

            // Set the image block's memory size.
            forwardRenderPassDescriptor.imageblockSampleLength = transparencyPipeline.imageblockSampleLength
        }

        do {
            let quadVertices: [Vertex] = [
                .init(position: .init(1, 0, -1, 0)),
                .init(position: .init(-1, 0, -1, 0)),
                .init(position: .init(-1, 0, 1, 0)),

                .init(position: .init(1, 0, -1, 0)),
                .init(position: .init(-1, 0, 1, 0)),
                .init(position: .init(1, 0, 1, 0))
            ]

            actorMesh = gpu.makeBuffer(data: quadVertices, options: .storageModeShared)
            actorMesh.label = "Quad Mesh"
        }
    }

    /// Delegate callback that responds to changes in the device's orientation or view size changes.
    func changeSize(size: CGSize) {
        let aspect = Float(size.width / size.height)
        projectionMatrix = matrix_perspective_left_hand(radians_from_degrees(65.0), aspect, 1.0, 150.0)
    }

    /// Updates the application's state for the current frame.
    func updateState(currentBufferIndex: Int) {
        let actorParams = actorParamsBuffers[currentBufferIndex]

        for i in 0..<opaqueActors.count {
            let translationMatrix = matrix4x4_translation(opaqueActors[i].position)
            let scaleMatrix = matrix4x4_scale(opaqueActors[i].scale)
            let rotationXMatrix = matrix4x4_rotation(radians_from_degrees(opaqueActors[i].rotation.x), 1.0, 0.0, 0.0)
            var rotationMatrix = matrix_multiply(matrix4x4_rotation(radians_from_degrees(rotation), 0.0, 1.0, 0.0), rotationXMatrix)

            // Last opaque actor is tbe floor which has no rotation.
            if i == opaqueActors.count - 1 {
                rotationMatrix = matrix_identity_float4x4
            }
            actorParams[i].modelMatrix = matrix_multiply(translationMatrix, matrix_multiply(rotationMatrix, scaleMatrix))
            actorParams[i].color = opaqueActors[i].color
        }

        for i in 0..<transparentActors.count {
            let paramsIndex = i + opaqueActors.count

            let translationMatrix = matrix4x4_translation(transparentActors[i].position)
            let scaleMatrix = matrix4x4_scale(transparentActors[i].scale)
            let rotationXMatrix = matrix4x4_rotation(radians_from_degrees(transparentActors[i].rotation.x), 1.0, 0.0, 0.0)
            let rotationMatrix = matrix_multiply(matrix4x4_rotation(radians_from_degrees(rotation), 0.0, 1.0, 0.0), rotationXMatrix)

            actorParams[paramsIndex].modelMatrix = matrix_multiply(translationMatrix, matrix_multiply(rotationMatrix, scaleMatrix))
            actorParams[paramsIndex].color = transparentActors[i].color
        }

        let eyePos = vector_float3(0.0, 2.0, -12.0)
        let eyeTarget = vector_float3(eyePos.x, eyePos.y - 0.25, eyePos.z + 1.0)
        let eyeUp = vector_float3(0.0, 1.0, 0.0)
        let viewMatrix = matrix_look_at_left_hand(eyePos, eyeTarget, eyeUp)

        cameraParamsBuffers[currentBufferIndex].contents = .init(
            cameraPos: eyePos,
            viewProjectionMatrix: matrix_multiply(projectionMatrix, viewMatrix)
        )

        if enableRotation {
            rotation += 1.0
        }
    }

    /// Draws all opaque meshes from the opaque actors array.
    func drawOpaqueObjects(renderEncoder: MTLRenderCommandEncoder, renderPipelineState: MTLRenderPipelineState) {
        renderEncoder.pushDebugGroup("Opaque Actor Rendering")
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setCullMode(.none)
        renderEncoder.setDepthStencilState(lessEqualDepthStencilState)

        for actorIndex in 0..<opaqueActors.count {
            let offsetValue = actorIndex * align(MemoryLayout<ActorParams>.size, BufferOffsetAlign)
            renderEncoder.setVertexBufferOffset(offsetValue, index: BufferIndices.ActorParams.rawValue)
            renderEncoder.setFragmentBufferOffset(offsetValue, index: BufferIndices.ActorParams.rawValue)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }
        renderEncoder.popDebugGroup()
    }

    /// Draws all the transparent meshes from the transparent actors array.
    func drawTransparentObjects(renderEncoder: MTLRenderCommandEncoder, renderPipelineState: MTLRenderPipelineState) {
        renderEncoder.pushDebugGroup("Transparent Actor Rendering")
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setCullMode(.none)

        // Only test the depth of the transparent geometry against the opaque geometry. This allows
        // transparent fragments behind other transparent fragments to be rasterized and stored in
        // the image block structure.
        renderEncoder.setDepthStencilState(noWriteLessEqualDepthStencilState)

        for actorIndex in 0..<transparentActors.count {
            let offsetValue = (actorIndex + opaqueActors.count) * align(MemoryLayout<ActorParams>.size, BufferOffsetAlign)
            renderEncoder.setVertexBufferOffset(offsetValue, index: BufferIndices.ActorParams.rawValue)
            renderEncoder.setFragmentBufferOffset(offsetValue, index: BufferIndices.ActorParams.rawValue)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }
        renderEncoder.popDebugGroup()
    }

    /// Binds the constant buffer the app needs to render the 3D actors.
    func bindCommonActorBuffers(renderEncoder: MTLRenderCommandEncoder, currentBufferIndex: Int) {
        let currentCameraBuffer = cameraParamsBuffers[currentBufferIndex].rawBuffer
        let currentActorParamBuffer = actorParamsBuffers[currentBufferIndex].rawBuffer

        renderEncoder.pushDebugGroup("Common Buffer Binding")
        renderEncoder.setVertexBuffer(actorMesh, offset: 0, index: BufferIndices.Vertices.rawValue)
        renderEncoder.setVertexBuffer(currentCameraBuffer, offset: 0, index: BufferIndices.CameraParams.rawValue)
        renderEncoder.setVertexBuffer(currentActorParamBuffer, offset: 0, index: BufferIndices.ActorParams.rawValue)
        renderEncoder.setFragmentBuffer(currentActorParamBuffer, offset: 0, index: BufferIndices.ActorParams.rawValue)
        renderEncoder.popDebugGroup()
    }

    /// Draws the opaque and transparent meshes with an explicit image block in a fragment function that implements order-independent transparency.
    func drawWithOrderIndependentTransparency(_ renderEncoder: MTLRenderCommandEncoder, currentBufferIndex: Int) {
        Debug.frameLog("drawTrans")

        // Initialize the image block's memory before rendering.
        renderEncoder.pushDebugGroup("Init Image Block")
        renderEncoder.setRenderPipelineState(initImageBlockPipeline)
        renderEncoder.dispatchThreadsPerTile(optimalTileSize)
        renderEncoder.popDebugGroup()

        bindCommonActorBuffers(renderEncoder: renderEncoder, currentBufferIndex: currentBufferIndex)
        drawOpaqueObjects(renderEncoder: renderEncoder, renderPipelineState: opaquePipeline)
        drawTransparentObjects(renderEncoder: renderEncoder, renderPipelineState: transparencyPipeline)

        renderEncoder.pushDebugGroup("Blend Fragments")
        renderEncoder.setRenderPipelineState(blendPipelineState)
        renderEncoder.setCullMode(.none)
        renderEncoder.setDepthStencilState(noDepthStencilState)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        renderEncoder.popDebugGroup()
    }

    /// Draws the opaque and transparent meshes with a pipeline's alpha blending.
    func drawUnorderedAlphaBlending(_ renderEncoder: MTLRenderCommandEncoder, currentBufferIndex: Int) {
        Debug.frameLog("drawBlend")
        bindCommonActorBuffers(renderEncoder: renderEncoder, currentBufferIndex: currentBufferIndex)
        drawOpaqueObjects(renderEncoder: renderEncoder, renderPipelineState: opaquePipeline)
        drawTransparentObjects(renderEncoder: renderEncoder, renderPipelineState: opaquePipeline)
    }

    func draw(
        toColor: MTLRenderPassColorAttachmentDescriptor,
        toDepth: MTLRenderPassDepthAttachmentDescriptor,
        using commandBuffer: MTLCommandBuffer, 
        frameIndex: Int,
        transparency: Bool
    ) {
        let encoder = {
            forwardRenderPassDescriptor.colorAttachments[RenderTargetIndices.Color.rawValue] = toColor
            forwardRenderPassDescriptor.depthAttachment = toDepth
            return commandBuffer.makeRenderCommandEncoderWithSafe(descriptor: forwardRenderPassDescriptor)
        }()
        encoder.label = "Forward Render Pass"

        if supportsOrderIndependentTransparency && transparency {
            drawWithOrderIndependentTransparency(encoder, currentBufferIndex: frameIndex)
        } else {
            drawUnorderedAlphaBlending(encoder, currentBufferIndex: frameIndex)
        }
        
        encoder.endEncoding()
    }
    
    func debugFrameStatus(){
        gpu.debugCountreSample(from: counterSampleBuffer)
    }
}
