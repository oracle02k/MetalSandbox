import MetalKit

class LifegameComputePass {
    typealias Functions = FunctionContainer<FunctionTable>

    enum RenderTargetIndices: Int {
        case Color = 0
    }

    enum VertexBufferIndices: Int {
        case GridParam = 0
        case OldField = 1
        case NewField = 2
    }

    enum FunctionTable: String, FunctionTableProvider {
        static var FileName: String = "lifegame.txt"
        case LifegameUpdate = "lifegame::update"
        case LifegameReset = "lifegame::reset"
    }

    struct GridParam {
        var Width: UInt16
        var Height: UInt16
    }

    private let gpu: GpuContext
    private let functions: Functions
    private lazy var gridParamBuffer: TypedBuffer<GridParam> = uninitialized()
    private lazy var oldFieldBuffer: MTLBuffer = uninitialized()
    private lazy var newFieldBuffer: MTLBuffer = uninitialized()
    private lazy var computeUpdatePipelineState: MTLComputePipelineState = uninitialized()
    private lazy var computeResetPipelineState: MTLComputePipelineState = uninitialized()
    private lazy var gridNum: Int = uninitialized()

    init (with gpu: GpuContext, functions: Functions) {
        self.gpu = gpu
        self.functions = functions
    }

    func build(width: Int, height: Int) {
        functions.build()

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

        gridNum = width * height
        newFieldBuffer = gpu.makeBuffer(length: sizeof(UInt16.self) * gridNum, options: [])

        gridParamBuffer = gpu.makeTypedBuffer(options: [])
        gridParamBuffer.contents.Width = UInt16(width)
        gridParamBuffer.contents.Height = UInt16(height)
    }

    func reset(using commandBuffer: MTLCommandBuffer) {
        let encoder = commandBuffer.makeComputeCommandEncoderWithSafe()
        encoder.setComputePipelineState(computeResetPipelineState)
        encoder.setBuffer(newFieldBuffer, offset: 0, index: VertexBufferIndices.NewField.rawValue)

        let gridSize = MTLSizeMake(gridNum, 1, 1) // 1Dgrid
        var threadGroupSize = computeUpdatePipelineState.maxTotalThreadsPerThreadgroup
        if threadGroupSize > gridNum {
            threadGroupSize = gridNum
        }
        let threadgroupSize = MTLSizeMake(threadGroupSize, 1, 1)
        encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
    }

    func update(using commandBuffer: MTLCommandBuffer) -> MTLBuffer {
        oldFieldBuffer = newFieldBuffer
        newFieldBuffer = gpu.makeBuffer(length: sizeof(UInt16.self) * gridNum, options: [])

        let encoder = commandBuffer.makeComputeCommandEncoderWithSafe()
        encoder.setComputePipelineState(computeUpdatePipelineState)
        encoder.setBuffer(gridParamBuffer.rawBuffer, offset: 0, index: VertexBufferIndices.GridParam.rawValue)
        encoder.setBuffer(oldFieldBuffer, offset: 0, index: VertexBufferIndices.OldField.rawValue)
        encoder.setBuffer(newFieldBuffer, offset: 0, index: VertexBufferIndices.NewField.rawValue)

        let gridSize = MTLSizeMake(gridNum, 1, 1) // 1Dgrid
        var threadGroupSize = computeUpdatePipelineState.maxTotalThreadsPerThreadgroup
        if threadGroupSize > gridNum {
            threadGroupSize = gridNum
        }
        let threadgroupSize = MTLSizeMake(threadGroupSize, 1, 1)
        encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()

        return newFieldBuffer
    }
}
