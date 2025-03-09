import MetalKit

class LifegameRenderPass {
    typealias Functions = FunctionContainer<FunctionTable>

    enum RenderTargetIndices: Int {
        case Color = 0
    }

    enum VertexBufferIndices: Int {
        case GridParam = 0
        case Field = 1
        case NewField = 2
    }

    enum FunctionTable: String, FunctionTableProvider {
        static var FileName: String = "lifegame.txt"
        case VertexShader = "lifegame::vertex_shader"
        case FragmentShader = "lifegame::fragment_shader"
        case LifegameUpdate = "lifegame::update"
        case LifegameReset = "lifegame::reset"
    }

    struct GridParam {
        var Width: UInt16
        var Height: UInt16
    }

    private let gpu: GpuContext
    private let functions: Functions
    private lazy var renderPipelineState: MTLRenderPipelineState = uninitialized()
    private lazy var renderPassDescriptor: MTLRenderPassDescriptor = uninitialized()
    private lazy var counterSampleBuffer: MTLCounterSampleBuffer? = uninitialized()
    private lazy var indexBuffer: TypedBuffer<UInt32> = uninitialized()
    private lazy var gridParamBuffer: TypedBuffer<GridParam> = uninitialized()
    private lazy var lifegame: Lifegame = uninitialized()
    private lazy var oldFieldBuffer: MTLBuffer = uninitialized()
    private lazy var newFieldBuffer: MTLBuffer = uninitialized()
    private lazy var computeUpdatePipelineState: MTLComputePipelineState = uninitialized()
    private lazy var computeResetPipelineState: MTLComputePipelineState = uninitialized()

    init (with gpu: GpuContext, functions: Functions) {
        self.gpu = gpu
        self.functions = functions
    }

    func build(width: Int, height: Int) {
        functions.build()

        renderPipelineState = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "Simple 2D Render Pipeline"
            descriptor.sampleCount = 1
            descriptor.vertexFunction = functions.find(by: .VertexShader)
            descriptor.fragmentFunction = functions.find(by: .FragmentShader)
            descriptor.colorAttachments[RenderTargetIndices.Color.rawValue].pixelFormat = .bgra8Unorm
            descriptor.depthAttachmentPixelFormat = .invalid
            return gpu.makeRenderPipelineState(descriptor)
        }()

        computeUpdatePipelineState = {
            let descriptor = MTLComputePipelineDescriptor()
            descriptor.computeFunction = functions.find(by: .LifegameUpdate)
            return gpu.makeComputePipelineState(descriptor)
        }()

        computeResetPipelineState = {
            let descriptor = MTLComputePipelineDescriptor()
            descriptor.computeFunction = functions.find(by: .LifegameReset)
            return gpu.makeComputePipelineState(descriptor)
        }()

        renderPassDescriptor = MTLRenderPassDescriptor()
        counterSampleBuffer = gpu.attachCounterSample(
            to: renderPassDescriptor,
            index: RenderTargetIndices.Color.rawValue
        )

        lifegame = Lifegame()
        lifegame.reset(width: width, height: height)
        newFieldBuffer = gpu.makeBuffer(data: lifegame.field.map {UInt16($0)}, options: [])

        gridParamBuffer = gpu.makeTypedBuffer(options: [])
        gridParamBuffer.contents.Width = UInt16(lifegame.gridWidth)
        gridParamBuffer.contents.Height = UInt16(lifegame.gridHeight)

        let quadW = lifegame.gridWidth - 1
        let quadH = lifegame.gridHeight - 1
        let quads = quadW * quadH
        let triangles = quads * 2
        let vertices = triangles * 3

        indexBuffer = gpu.makeTypedBuffer(elementCount: vertices, options: [])
        var index = 0
        var offset: UInt32 = 0
        for _ in 0..<lifegame.gridHeight-1 {
            for i: UInt32 in 0..<UInt32(lifegame.gridWidth-1) {
                indexBuffer[index] = i + offset
                indexBuffer[index+1] = i + UInt32(lifegame.gridWidth) + offset
                indexBuffer[index+2] = i + 1 + offset
                indexBuffer[index+3] = i + 1 + offset
                indexBuffer[index+4] = i + UInt32(lifegame.gridWidth) + offset
                indexBuffer[index+5] = i + UInt32(lifegame.gridWidth) + 1 + offset
                index += 6
            }
            offset += UInt32(lifegame.gridWidth)
        }

        renderPassDescriptor = MTLRenderPassDescriptor()
    }

    func draw(fieldBuffer: MTLBuffer, toColor: MTLRenderPassColorAttachmentDescriptor, using commandBuffer: MTLCommandBuffer) {
        let encoder = {
            renderPassDescriptor.colorAttachments[RenderTargetIndices.Color.rawValue] = toColor
            return commandBuffer.makeRenderCommandEncoderWithSafe(descriptor: renderPassDescriptor)
        }()

        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setVertexBuffer(gridParamBuffer.rawBuffer, offset: 0, index: VertexBufferIndices.GridParam.rawValue)
        encoder.setVertexBuffer(fieldBuffer, offset: 0, index: VertexBufferIndices.Field.rawValue)
        encoder.drawIndexedPrimitives(
            type: .line,
            indexCount: indexBuffer.count,
            indexType: .uint32,
            indexBuffer: indexBuffer.rawBuffer,
            indexBufferOffset: 0
        )
        encoder.endEncoding()
    }
}
