import Foundation
import simd
import Metal

class IndirectScene {
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
    
    private var vertices = [GpuTypedTransientHeapBlock<Vertex>]()
    private var frameStateBuffer = [FrameState]()
    private lazy var objectParameters: GpuTypedTransientHeapBlock<ObjectPerameters> = uninitialized()
    // When using an indirect command buffer encoded by the CPU, buffer updated by the CPU must be
    // blit into a seperate buffer that is set in the indirect command buffer.
    private lazy var indirectFrameStateBuffer: MTLBuffer = uninitialized()
    // The indirect command buffer encoded and executed
    private lazy var indirectCommandBuffer: MTLIndirectCommandBuffer = uninitialized()
    // aspectScale
    private lazy var aspectScale = simd_float2(1, 1)
    
    let allocator: GpuTransientAllocator
    
    
    init(allocator: GpuTransientAllocator){
        self.allocator = allocator
    }
    
    func build(){
        allocator.build(size: 1024)
    }
    
    func gearSetup() {
        for objectIdx in 0..<NumObjects {
            // Choose parameters to generate a mesh for this object so that each mesh is unique
            // and looks diffent than the mesh it's next to in the grid drawn
            let numTeeth = (objectIdx < 8) ? objectIdx + 3 : objectIdx * 3
            
            // Create a vertex buffer, and initialize it with a unique 2D gear mesh
            vertices.append(newGearMeshWithNumTeeth(numTeeth))
        }
        
        let gridDimensions = simd_float2(GridWidth, GridHeight)
        let offset = (ObjecDistance / 2.0) * (gridDimensions-1)
        
        /// Create and fill array containing parameters for each object
        objectParameters = allocator.allocateTypedBuffer(
            of: ObjectPerameters.self, 
            length: NumObjects
        ) {  parameters in
            for objectIdx in 0..<NumObjects {
                // Calculate position of each object such that each occupies a space in a grid
                let gridPos = simd_float2(Float(objectIdx % Int(GridWidth)), Float(objectIdx / Int(GridWidth)))
                let position = -offset + gridPos * ObjecDistance
                // Write the position of each object to the object parameter buffer
                parameters[objectIdx].position = position
            }
        }
    }
    
    func indirectSetup(device: MTLDevice) {
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
        
        indirectCommandBuffer = device.makeIndirectCommandBuffer(
            descriptor: icbDescriptor,
            maxCommandCount: NumObjects
        )!
        indirectCommandBuffer.label = "Scene ICB"
        
        //  Encode a draw command for each object drawn in the indirect command buffer.
        for objIndex in 0..<NumObjects {
            let ICBCommand = indirectCommandBuffer.indirectRenderCommandAt(objIndex)
            let binding = vertices[objIndex].binding()
            let paramBinding = objectParameters.binding()
            let verticesIndex = VertexBufferIndex.Vertices.rawValue
            let frameStateIndex = VertexBufferIndex.FrameState.rawValue
            let objectParamsIndex = VertexBufferIndex.ObjectParams.rawValue
            
            ICBCommand.setVertexBuffer(binding.buffer, offset: binding.offset, at: verticesIndex)
            ICBCommand.setVertexBuffer(indirectFrameStateBuffer, offset: 0, at: frameStateIndex)
            ICBCommand.setVertexBuffer(paramBinding.buffer, offset: paramBinding.offset, at: objectParamsIndex)
            ICBCommand.drawPrimitives(
                MTLPrimitiveType.triangle,
                vertexStart: 0,
                vertexCount: vertices[objIndex].typedBufferCount(),
                instanceCount: 1,
                baseInstance: objIndex
            )
        }
    }
    
    func update(){
        
    }
    
    func changeSize(size: CGSize) {
        //let aspect = Float(size.width / size.height)
        //projectionMatrix = matrix_perspective_left_hand(radians_from_degrees(65.0), aspect, 1.0, 150.0)
    }
    
    func draw(_ renderCommandBuilder: RenderCommandBuilder) {
        renderCommandBuilder.withStateScope { builder in
            builder.withRenderPipelineState { d in
                d.label = "Instance Render Pipeline"
                d.vertexFunction = builder.findFunction(by: .IndirectVSWithInstance)
                d.fragmentFunction = builder.findFunction(by: .IndirectFS)
                d.colorAttachments[0].pixelFormat = .bgra8Unorm
                d.depthAttachmentPixelFormat = .depth32Float
                // Needed for this pipeline state to be used in indirect command buffers.
                d.supportIndirectCommandBuffers = true
            }
            
            builder.withDepthStencilState { d in
                d.label = "Depth"
                d.depthCompareFunction = .lessEqual
                d.isDepthWriteEnabled = true
            }
            
            /*
             // When encoding commands with the CPU, the app sets this indirect frame state buffer
             // dynamically in the indirect command buffer.   Each frame data will be blit from the
             // _frameStateBuffer that has just been updated by the CPU to this buffer.  This allow
             // a synchronous update of values set by the CPU.
             indirectFrameStateBuffer = gpu.makeBuffer(
             length: MemoryLayout<FrameState>.stride,
             options: .storageModePrivate
             )
             indirectFrameStateBuffer.label = "Indirect Frame State Buffer"
             */
            
        }
    }
    
    /// Create a Metal buffer containing a 2D "gear" mesh
    func newGearMeshWithNumTeeth(_ numTeeth: Int) -> GpuTypedTransientHeapBlock<Vertex> {
        // NSAssert(numTeeth >= 3, "Can only build a gear with at least 3 teeth")
        let innerRatio: Float = 0.8
        let toothWidth: Float = 0.25
        let toothSlope: Float = 0.2
        
        // For each tooth, this function generates 2 triangles for tooth itself, 1 triangle to fill
        // the inner portion of the gear from bottom of the tooth to the center of the gear,
        // and 1 triangle to fill the inner portion of the gear below the groove beside the tooth.
        // Hence, the buffer needs 4 triangles or 12 vertices for each tooth.
        let numVertices = numTeeth * 12
        let angle = Float(2.0 * Double.pi/Double(numTeeth))
        let origin = packed_float2(0.0, 0.0)
        var vtx = 0
        
        return allocator.allocateTypedBuffer(length: numVertices) { meshVertices in
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
                let groove1    = packed_float2( sin(toothStartAngle)*innerRatio, cos(toothStartAngle)*innerRatio )
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
        }
    }
}
