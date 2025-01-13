import MetalKit

class CheckComputePass {
    typealias Functions = FunctionContainer<FunctionNames>

    enum FunctionNames: String, CaseIterable {
        case Convert = "convert"
    }

    struct GridParam {
        var Width: UInt16
        var Height: UInt16
    }

    private let gpu: GpuContext
    private let functions: Functions
    private lazy var computePipelineState: MTLComputePipelineState =        uninitialized()
    private(set) lazy var inputTexture: MTLTexture = uninitialized()
    private(set) lazy var outputTexture: MTLTexture = uninitialized()

    init(with gpu: GpuContext, functions: Functions) {
        self.gpu = gpu
        self.functions = functions
    }

    func build() {
        functions.build(fileName: "check.txt")

        computePipelineState = {
            let descriptor = MTLComputePipelineDescriptor()
            descriptor.computeFunction = functions.find(by: .Convert)
            return gpu.makeComputePipelineState(descriptor)
        }()

        // 入力テクスチャ
        do {
            let loader = MTKTextureLoader(device: gpu.device)
            inputTexture = try loader.newTexture(name: "check32_white", scaleFactor: 1.0, bundle: nil, options: nil)
        } catch {
            appFatalError("faild to make texture.", error: error)
        }

        // 画像変換後のテクスチャのバッファを確保
        let colorDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Const.textureWidth,
            height: Const.textureHeight,
            mipmapped: false)
        colorDesc.usage = [.shaderRead, .shaderWrite]
        outputTexture = gpu.makeTexture(colorDesc)
    }

    func convert(_ commandBuffer: MTLCommandBuffer) {
        // コマンド送信
        let computeEncoder = commandBuffer.makeComputeCommandEncoderWithSafe()
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setTexture(inputTexture, index: 0)
        computeEncoder.setTexture(outputTexture, index: 1)

        let threadWidth = computePipelineState.threadExecutionWidth
        let threadHeight = computePipelineState.maxTotalThreadsPerThreadgroup / threadWidth
        let threadsPerThreadgroup = MTLSizeMake(threadWidth, threadHeight, 1)
        let threadsPerGrid = MTLSizeMake(Const.textureWidth, Const.textureHeight, 1)

        if gpu.device.supportsFamily(.apple4) {
            // A11以降で　non-uniform　に対応している
            computeEncoder.dispatchThreads(
                threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        } else {
            let threadgroupsPerGrid = MTLSizeMake(
                (Const.textureWidth + threadWidth - 1) / threadWidth,
                (Const.textureHeight + threadHeight - 1) / threadHeight,
                1)
            computeEncoder.dispatchThreadgroups(
                threadgroupsPerGrid,
                threadsPerThreadgroup: threadsPerThreadgroup)
        }
        computeEncoder.endEncoding()
    }
}
