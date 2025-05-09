import MetalKit

class IndirectRenderPass {
    typealias Functions = FunctionContainer<FunctionTable>

    enum FunctionTable: String, FunctionTableProvider {
        static let FileName = "indirect.txt"
        case VertexShaderWithInstance = "indirect::vertex_shader_with_instance"
        case VertexShader = "indirect::vertex_shader"
        case FragmentShader = "indirect::fragment_shader"
    }

    enum VertexBufferIndex: Int {
        case Vertices = 0
        case ObjectParams
        case FrameState
    }

    enum RenderTargetIndices: Int {
        case Color           = 0
    }

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

    var NumObjects: Int {Int(GridWidth * GridHeight)}
    let GridWidth: Float = 20
    let GridHeight: Float = 20
    let ObjecDistance: Float = 2.1 // Distance between each object

    private let gpu: GpuContext
    private var screenViewport: Viewport
    private let functions: Functions
    private lazy var renderPipelineState: MTLRenderPipelineState = uninitialized()
    private lazy var depthStencilState: MTLDepthStencilState = uninitialized()
    private lazy var renderPassDescriptor: MTLRenderPassDescriptor = uninitialized()
    private var vertices = [TypedBuffer<Vertex>]()
    private var frameStateBuffer = [TypedBuffer<FrameState>]()
    private lazy var objectParameters: TypedBuffer<ObjectPerameters> = uninitialized()
    private lazy var inFlightSemaphore: DispatchSemaphore = uninitialized()
    // When using an indirect command buffer encoded by the CPU, buffer updated by the CPU must be
    // blit into a seperate buffer that is set in the indirect command buffer.
    private lazy var indirectFrameStateBuffer: MTLBuffer = uninitialized()
    // The indirect command buffer encoded and executed
    private lazy var indirectCommandBuffer: MTLIndirectCommandBuffer = uninitialized()
    // aspectScale
    private lazy var aspectScale = simd_float2(1, 1)

    init (with gpu: GpuContext, functions: Functions) {
        self.gpu = gpu
        self.functions = functions
        screenViewport = .init(leftTop: .init(0, 0), rightBottom: .init(320, 320))
    }

    func build(maxFramesInFlight: Int) {
        functions.build()
        renderPipelineState = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "Simple 2D Render Pipeline"
            descriptor.sampleCount = 1
            descriptor.vertexFunction = functions.find(by: .VertexShaderWithInstance)
            descriptor.fragmentFunction = functions.find(by: .FragmentShader)
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.depthAttachmentPixelFormat = .depth32Float
            // Needed for this pipeline state to be used in indirect command buffers.
            descriptor.supportIndirectCommandBuffers = true
            return gpu.makeRenderPipelineState(descriptor)
        }()

        depthStencilState = {
            let descriptor = MTLDepthStencilDescriptor()
            descriptor.label = "Depth"
            descriptor.depthCompareFunction = .lessEqual
            descriptor.isDepthWriteEnabled = true
            return gpu.makeDepthStancilState(descriptor)
        }()

        renderPassDescriptor = MTLRenderPassDescriptor()

        for i in 0..<maxFramesInFlight {
            frameStateBuffer.append(gpu.makeTypedBuffer(options: .storageModeShared))
            frameStateBuffer[i].rawBuffer.label = "Frame state buffer \(i)"
        }

        // When encoding commands with the CPU, the app sets this indirect frame state buffer
        // dynamically in the indirect command buffer.   Each frame data will be blit from the
        // _frameStateBuffer that has just been updated by the CPU to this buffer.  This allow
        // a synchronous update of values set by the CPU.
        indirectFrameStateBuffer = gpu.makeBuffer(
            length: MemoryLayout<FrameState>.stride,
            options: .storageModePrivate
        )
        indirectFrameStateBuffer.label = "Indirect Frame State Buffer"

        aspectScale.x = 1
        aspectScale.y = 1

        gearSetup()
        indirectSetup()
    }

    func gearSetup() {
        for objectIdx in 0..<NumObjects {
            // Choose parameters to generate a mesh for this object so that each mesh is unique
            // and looks diffent than the mesh it's next to in the grid drawn
            let numTeeth = (objectIdx < 8) ? objectIdx + 3 : objectIdx * 3

            // Create a vertex buffer, and initialize it with a unique 2D gear mesh
            vertices.append(newGearMeshWithNumTeeth(numTeeth))
            vertices[objectIdx].rawBuffer.label = "Object \(objectIdx) Buffer"
        }

        /// Create and fill array containing parameters for each object
        objectParameters = gpu.makeTypedBuffer(elementCount: NumObjects, options: []) as TypedBuffer<ObjectPerameters>
        objectParameters.rawBuffer.label = "Object Parameters Array"

        let gridDimensions = simd_float2(GridWidth, GridHeight)
        let offset = (ObjecDistance / 2.0) * (gridDimensions-1)

        for objectIdx in 0..<NumObjects {
            // Calculate position of each object such that each occupies a space in a grid
            let gridPos = simd_float2(Float(objectIdx % Int(GridWidth)), Float(objectIdx / Int(GridWidth)))
            let position = -offset + gridPos * ObjecDistance
            // Write the position of each object to the object parameter buffer
            objectParameters[objectIdx].position = position
        }
    }

    func indirectSetup() {
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

        indirectCommandBuffer = gpu.device.makeIndirectCommandBuffer(
            descriptor: icbDescriptor,
            maxCommandCount: NumObjects
        )!
        indirectCommandBuffer.label = "Scene ICB"

        //  Encode a draw command for each object drawn in the indirect command buffer.
        for objIndex in 0..<NumObjects {
            let ICBCommand = indirectCommandBuffer.indirectRenderCommandAt(objIndex)
            ICBCommand.setVertexBuffer(vertices[objIndex].rawBuffer, offset: 0, at: VertexBufferIndex.Vertices.rawValue)
            ICBCommand.setVertexBuffer(indirectFrameStateBuffer, offset: 0, at: VertexBufferIndex.FrameState.rawValue)
            ICBCommand.setVertexBuffer(objectParameters.rawBuffer, offset: 0, at: VertexBufferIndex.ObjectParams.rawValue)
            ICBCommand.drawPrimitives(
                MTLPrimitiveType.triangle,
                vertexStart: 0,
                vertexCount: vertices[objIndex].count,
                instanceCount: 1,
                baseInstance: objIndex
            )
        }
    }

    func updateAspectScale(_ size: CGSize) {
        aspectScale = simd_float2(Float(size.height / size.width), 1.0)
    }

    /// Updates non-Metal state for the current frame including updates to uniforms used in shaders
    func update() {
    }

    func preparaToDraw(using commandBuffer: MTLCommandBuffer, frameIndex: Int) {
        let encoder = commandBuffer.makeBlitCommandEncoderWithSafe()
        frameStateBuffer[frameIndex].contents.aspectScale = aspectScale
        encoder.copy(
            from: frameStateBuffer[frameIndex].rawBuffer, sourceOffset: 0,
            to: indirectFrameStateBuffer, destinationOffset: 0,
            size: indirectFrameStateBuffer.length
        )
        encoder.endEncoding()
    }

    func draw(
        toColor: MTLRenderPassColorAttachmentDescriptor,
        toDepth: MTLRenderPassDepthAttachmentDescriptor,
        using commandBuffer: MTLCommandBuffer,
        indirect: Bool
    ) {
        let encoder = {
            renderPassDescriptor.colorAttachments[RenderTargetIndices.Color.rawValue] = toColor
            renderPassDescriptor.depthAttachment = toDepth
            return commandBuffer.makeRenderCommandEncoderWithSafe(descriptor: renderPassDescriptor)
        }()

        encoder.setCullMode(.back)
        encoder.setRenderPipelineState(renderPipelineState)

        if indirect {
            indirectDraw(encoder)
        } else {
            normalDraw(encoder)
        }

        encoder.endEncoding()
    }

    func normalDraw(_ encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBuffer(indirectFrameStateBuffer, offset: 0, index: VertexBufferIndex.FrameState.rawValue)
        encoder.setVertexBuffer(objectParameters.rawBuffer, offset: 0, index: VertexBufferIndex.ObjectParams.rawValue)

        for i in 0..<NumObjects {
            encoder.setVertexBuffer(vertices[i].rawBuffer, offset: 0, index: VertexBufferIndex.Vertices.rawValue)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices[i].count, instanceCount: 1, baseInstance: i)
        }
    }

    func indirectDraw(_ encoder: MTLRenderCommandEncoder) {
        // Make a useResource call for each buffer needed by the indirect command buffer.
        for i in 0..<NumObjects {
            encoder.useResource(vertices[i].rawBuffer, usage: .read, stages: [.fragment, .vertex])
        }
        encoder.useResource(objectParameters.rawBuffer, usage: .read)
        encoder.useResource(indirectFrameStateBuffer, usage: .read)
        // Draw everything in the indirect command buffer.
        encoder.executeCommandsInBuffer(indirectCommandBuffer, range: 0..<NumObjects)
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
        let meshVertices: TypedBuffer<Vertex> = gpu.makeTypedBuffer(elementCount: numVertices, options: [])
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
}
