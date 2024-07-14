import MetalKit

class OriginIndirectRenderer {
    let NumObjects = 15
    let GridWidth: Float = 5
    var GridHeight: Float { ((Float(NumObjects)+GridWidth-1)/GridWidth) }
    let ViewScale: Float = 0.25    // Scale of each object when drawn
    let ObjectSize: Float = 2.0    // Because the objects are centered at origin, the scale applicedstatic
    let ObjecDistance: Float = 2.1 // Distance between each object
    let MaxFramesInFlight = 3

    // Structure defining the layout of each vertex.  Shared between C code filling in the vertex data
    //   and Metal vertex shader consuming the vertices
    struct Vertex {
        var position: packed_float2
        var texcoord: packed_float2
    }

    // Structure defining the layout of variable changing once (or less) per frame
    struct FrameState {
        var aspectScale: simd_float2
    }

    // Structure defining parameters for each rendered object
    struct ObjectPerameters {
        var position: packed_float2
    }

    // Buffer index values shared between the vertex shader and C code
    enum VertexBufferIndex: Int {
        case Vertices = 0
        case ObjectParams
        case FrameState
    }

    // Buffer index values shared between the compute kernel and C code
    enum KernelBufferIndex: Int {
        case FrameState = 0
        case ObjectParams
        case Arguments
    }

    enum ArgumentBufferBufferID: Int {
        case CommandBuffer = 0
        case ObjectMesh
    }

    private let pipelineStateFactory: MetalPipelineStateFactory
    private let resourceFactory: MetalResourceFactory

    // Index into per frame uniforms to use for the current frame
    private var inFlightIndex: Int = 0

    // Number of frames rendered
    private var frameNumber: Int = 0

    // Array of Metal buffers storing vertex data for each rendered object
    private var vertexBuffer: [TypedBuffer<Vertex>?]

    // The Metal buffers storing per frame uniform data
    private var frameStateBuffer: [TypedBuffer<FrameState>?]

    private lazy var  inFlightSemaphore: DispatchSemaphore = uninitialized()

    // The Metal buffer storing per object parameters for each rendered object
    private lazy var objectParameters: TypedBuffer<ObjectPerameters> = uninitialized()

    // Render pipeline executinng indirect command buffer
    private lazy var renderPipelineState: MTLRenderPipelineState = uninitialized()

    // When using an indirect command buffer encoded by the CPU, buffer updated by the CPU must be
    // blit into a seperate buffer that is set in the indirect command buffer.
    private lazy var indirectFrameStateBuffer: MTLBuffer = uninitialized()

    // The indirect command buffer encoded and executed
    private lazy var indirectCommandBuffer: MTLIndirectCommandBuffer = uninitialized()

    private lazy var aspectScale: simd_float2 = uninitialized()

    init(
        pipelineStateFactory: MetalPipelineStateFactory,
        resourceFactory: MetalResourceFactory
    ) {
        self.pipelineStateFactory = pipelineStateFactory
        self.resourceFactory = resourceFactory

        self.vertexBuffer = .init(repeating: nil, count: NumObjects)
        self.frameStateBuffer = .init(repeating: nil, count: MaxFramesInFlight)
    }

    func build() {
        inFlightSemaphore = DispatchSemaphore(value: MaxFramesInFlight)

        // Create a reusable pipeline state
        renderPipelineState = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "IndirectPipeline"
            descriptor.sampleCount = 1// view.sampleCount
            descriptor.vertexFunction = pipelineStateFactory.findFunction(by: .IndirectRendererVertexFunction)
            descriptor.fragmentFunction = pipelineStateFactory.findFunction(by: .IndirectRendererFragmentFunction)
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm// view.colorPixelFormat
            descriptor.depthAttachmentPixelFormat = .depth32Float// view.depthStencilPixelFormat
            // Needed for this pipeline state to be used in indirect command buffers.
            descriptor.supportIndirectCommandBuffers = true
            return pipelineStateFactory.makeRenderPipelineState(descriptor)
        }()

        for objectIdx in 0..<NumObjects {
            // Choose parameters to generate a mesh for this object so that each mesh is unique
            // and looks diffent than the mesh it's next to in the grid drawn
            let numTeeth = (objectIdx < 8) ? objectIdx + 3 : objectIdx * 3

            // Create a vertex buffer, and initialize it with a unique 2D gear mesh
            vertexBuffer[objectIdx] = newGearMeshWithNumTeeth(numTeeth)
            vertexBuffer[objectIdx]?.rawBuffer.label = "Object \(objectIdx) Buffer"
        }

        /// Create and fill array containing parameters for each object
        objectParameters = resourceFactory.makeTypedBuffer(elementCount: NumObjects, options: []) as TypedBuffer<ObjectPerameters>
        objectParameters.rawBuffer.label = "Object Parameters Array"

        let gridDimensions = simd_float2(GridWidth, GridHeight)
        let offset = ObjecDistance / 2.0 * (gridDimensions-1)

        for objectIdx in 0..<NumObjects {
            // Calculate position of each object such that each occupies a space in a grid
            let gridPos = simd_float2(Float(objectIdx % Int(GridWidth)), Float(objectIdx) / GridWidth)
            let position = -offset + gridPos * ObjecDistance

            // Write the position of each object to the object parameter buffer
            objectParameters[objectIdx].position = position
        }

        for i in 0..<MaxFramesInFlight {
            frameStateBuffer[i] = resourceFactory.makeTypedBuffer(options: .storageModeShared) as TypedBuffer<FrameState>
            frameStateBuffer[i]?.rawBuffer.label = "Frame state buffer \(i)"
        }

        // When encoding commands with the CPU, the app sets this indirect frame state buffer
        // dynamically in the indirect command buffer.   Each frame data will be blit from the
        // _frameStateBuffer that has just been updated by the CPU to this buffer.  This allow
        // a synchronous update of values set by the CPU.
        indirectFrameStateBuffer = resourceFactory.makeBuffer(
            length: MemoryLayout<FrameState>.stride,
            options: .storageModePrivate
        )
        indirectFrameStateBuffer.label = "Indirect Frame State Buffer"

        let icbDescriptor = MTLIndirectCommandBufferDescriptor()

        // Indicate that the only draw commands will be standard (non-indexed) draw commands.
        icbDescriptor.commandTypes = .draw

        // Indicate that buffers will be set for each command IN the indirect command buffer.
        icbDescriptor.inheritBuffers = false

        // Indicate that a max of 3 buffers will be set for each command.
        icbDescriptor.maxVertexBufferBindCount = 3
        icbDescriptor.maxFragmentBufferBindCount = 0

        // Indicate that the render pipeline state object will be set in the render command encoder
        // (not by the indirect command buffer).
        // On iOS, this property only exists on iOS 13 and later.  It defaults to YES in earlier
        // versions
        if #available(iOS 13.0, *) {
            icbDescriptor.inheritPipelineState = true
        }

        indirectCommandBuffer = resourceFactory.device.makeIndirectCommandBuffer(
            descriptor: icbDescriptor,
            maxCommandCount: NumObjects
        )!
        indirectCommandBuffer.label = "Scene ICB"

        //  Encode a draw command for each object drawn in the indirect command buffer.
        for objIndex in 0..<NumObjects {
            let ICBCommand = indirectCommandBuffer.indirectRenderCommandAt(objIndex)

            ICBCommand.setVertexBuffer(vertexBuffer[objIndex]!.rawBuffer, offset: 0, at: VertexBufferIndex.Vertices.rawValue)
            ICBCommand.setVertexBuffer(indirectFrameStateBuffer, offset: 0, at: VertexBufferIndex.FrameState.rawValue)
            ICBCommand.setVertexBuffer(objectParameters.rawBuffer, offset: 0, at: VertexBufferIndex.ObjectParams.rawValue)

            let vertexCount = vertexBuffer[objIndex]!.rawBuffer.length/MemoryLayout<Vertex>.stride
            ICBCommand.drawPrimitives(
                MTLPrimitiveType.triangle,
                vertexStart: 0,
                vertexCount: vertexCount,
                instanceCount: 1,
                baseInstance: objIndex
            )
        }
    }

    /// Create a Metal buffer containing a 2D "gear" mesh
    func newGearMeshWithNumTeeth(_ numTeeth: Int) -> TypedBuffer<Vertex> {
        // NSAssert(numTeeth >= 3, "Can only build a gear with at least 3 teeth")

        let innerRatio: Float = 0.8
        let toothWidth: Float = 0.25
        let toothSlope: Float = 0.2

        // For each tooth, this function generates 2 triangles for tooth itself, 1 triangle to fill
        // the inner portion of the gear from bottom of the tooth to the center of the gear,
        // and 1 triangle to fill the inner portion of the gear below the groove beside the tooth.
        // Hence, the buffer needs 4 triangles or 12 vertices for each tooth.
        let numVertices = numTeeth * 12
        let meshVertices: TypedBuffer<Vertex> = resourceFactory.makeTypedBuffer(elementCount: numVertices, options: [])
        meshVertices.rawBuffer.label = "\(numTeeth) Toothed Cog Vertices"

        let angle = Float(2.0 * Double.pi/Double(numTeeth))
        let origin = packed_float2(0.0, 0.0)
        var vtx = 0

        // Build triangles for teeth of gear
        for itooth in 0..<numTeeth {
            let tooth: Float = Float(itooth)
            // Calculate angles for tooth and groove
            let toothStartAngle: Float = tooth * angle
            let toothTip1Angle: Float  = (tooth+toothSlope) * angle
            let toothTip2Angle: Float  = (tooth+toothSlope+toothWidth) * angle
            let toothEndAngle: Float   = (tooth+2*toothSlope+toothWidth) * angle
            let nextToothAngle: Float  = (tooth+1.0) * angle

            // Calculate positions of vertices needed for the tooth
            let  groove1    = packed_float2( sin(toothStartAngle)*innerRatio, cos(toothStartAngle)*innerRatio )
            let tip1       = packed_float2( sin(toothTip1Angle), cos(toothTip1Angle) )
            let tip2       = packed_float2(sin(toothTip2Angle), cos(toothTip2Angle) )
            let groove2    = packed_float2( sin(toothEndAngle)*innerRatio, cos(toothEndAngle)*innerRatio )
            let nextGroove = packed_float2( sin(nextToothAngle)*innerRatio, cos(nextToothAngle)*innerRatio )

            // Right top triangle of tooth
            meshVertices[vtx].position = groove1
            meshVertices[vtx].texcoord = (groove1 + 1.0) / 2.0
            vtx += 1

            meshVertices[vtx].position = tip1
            meshVertices[vtx].texcoord = (tip1 + 1.0) / 2.0
            vtx += 1

            meshVertices[vtx].position = tip2
            meshVertices[vtx].texcoord = (tip2 + 1.0) / 2.0
            vtx += 1

            // Left bottom triangle of tooth
            meshVertices[vtx].position = groove1
            meshVertices[vtx].texcoord = (groove1 + 1.0) / 2.0
            vtx += 1

            meshVertices[vtx].position = tip2
            meshVertices[vtx].texcoord = (tip2 + 1.0) / 2.0
            vtx += 1

            meshVertices[vtx].position = groove2
            meshVertices[vtx].texcoord = (groove2 + 1.0) / 2.0
            vtx += 1

            // Slice of circle from bottom of tooth to center of gear
            meshVertices[vtx].position = origin
            meshVertices[vtx].texcoord = (origin + 1.0) / 2.0
            vtx += 1

            meshVertices[vtx].position = groove1
            meshVertices[vtx].texcoord = (groove1 + 1.0) / 2.0
            vtx += 1

            meshVertices[vtx].position = groove2
            meshVertices[vtx].texcoord = (groove2 + 1.0) / 2.0
            vtx += 1

            // Slice of circle from the groove to the center of gear
            meshVertices[vtx].position = origin
            meshVertices[vtx].texcoord = (origin + 1.0) / 2.0
            vtx += 1

            meshVertices[vtx].position = groove2
            meshVertices[vtx].texcoord = (groove2 + 1.0) / 2.0
            vtx += 1

            meshVertices[vtx].position = nextGroove
            meshVertices[vtx].texcoord = (nextGroove + 1.0) / 2.0
            vtx += 1
        }

        return meshVertices
    }

    /// Updates non-Metal state for the current frame including updates to uniforms used in shaders
    func updateState() {
        frameNumber += 1
        inFlightIndex = frameNumber % MaxFramesInFlight
        var frameStete = frameStateBuffer[inFlightIndex]!.contents
        frameStete.aspectScale = aspectScale
    }

    func updateAspectScale(_ size: CGSize) {
        aspectScale = simd_float2(Float(size.height / size.width), 1.0)
    }

    func draw(_ commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
        // Wait to ensure only AAPLMaxFramesInFlight are getting processed by any stage in the Metal
        //   pipeline (App, Metal, Drivers, GPU, etc)
        inFlightSemaphore.wait()
        updateState()
        Debug.frameLog("frame: \(frameNumber)")
        Debug.frameLog("inFlightIndex: \(inFlightIndex)")

        // Add completion hander which signals _inFlightSemaphore when Metal and the GPU has fully
        // finished processing the commands encoded this frame.  This indicates when the dynamic
        // _frameStateBuffer, that written by the CPU in this frame, has been read by Metal and the GPU
        // meaning we can change the buffer contents without corrupting the rendering
        commandBuffer.addCompletedHandler {_ in
            self.inFlightSemaphore.signal()
        }

        /// Encode blit commands to update the buffer holding the frame state.
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!

        blitEncoder.copy(
            from: frameStateBuffer[inFlightIndex]!.rawBuffer, sourceOffset: 0,
            to: indirectFrameStateBuffer, destinationOffset: 0,
            size: indirectFrameStateBuffer.length
        )
        blitEncoder.endEncoding()

        // If we've gotten a renderPassDescriptor we can render to the drawable, otherwise we'll skip
        //   any rendering this frame because we have no drawable to draw to

        // Create a render command encoder so we can render into something
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.label = "Main Render Encoder"
        renderEncoder.setCullMode(.back)
        renderEncoder.setRenderPipelineState(renderPipelineState)

        // Make a useResource call for each buffer needed by the indirect command buffer.
        for i in 0..<NumObjects {
            renderEncoder.useResource(vertexBuffer[i]!.rawBuffer, usage: .read)
        }
        renderEncoder.useResource(objectParameters.rawBuffer, usage: .read)
        renderEncoder.useResource(indirectFrameStateBuffer, usage: .read)

        // Draw everything in the indirect command buffer.
        renderEncoder.executeCommandsInBuffer(indirectCommandBuffer, range: 0..<NumObjects)

        // We're done encoding commands
        renderEncoder.endEncoding()

    }

}
