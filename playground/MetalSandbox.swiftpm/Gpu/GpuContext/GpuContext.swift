import SwiftUI

struct GpuEnv {
    let sharedAllocatorSize: Int = 1024 * 1024 * 10 // 10MiByte
    let privateAllocatorSize: Int = 1024 * 1024 * 10 // 10MiByte
    let frame = GpuFrameEnv(
        sharedAllocatorSize: 1024 * 1024 * 10, // 10MiByte
        privateAllocatorSize: 1024 * 1024 * 10 // 10MiByte
    )
}

class GpuContext {
    let deviceResolver: MetalDeviceResolver
    var device: MTLDevice { deviceResolver.resolve() }
    lazy var sharedAllocator: GpuTransientAllocator = uninitialized()
    lazy var privateAllocator: GpuTransientAllocator = uninitialized()
    lazy var renderStateResolver: GpuRenderStateResolver = uninitialized()
    lazy var functions: GpuFunctions = uninitialized()
    lazy var frame: GpuFrameContext = uninitialized()
    lazy var taskQueue: GpuTaskQueue = uninitialized()
    lazy var renderQueue: GpuRenderQueue = uninitialized()
    var counterSampler: GpuCounterSampler?

    private lazy var commandQueue: MTLCommandQueue = uninitialized()

    init(deviceResolver: MetalDeviceResolver) {
        self.deviceResolver = deviceResolver
    }

    func build(env: GpuEnv = GpuEnv()) {
        let device = deviceResolver.resolve()

        guard let commandQueue = device.makeCommandQueue() else {
            appFatalError("failed to make command queue.")
        }
        self.commandQueue = commandQueue

        sharedAllocator = .init(makeBuffer(length: env.sharedAllocatorSize, options: .storageModeShared))
        privateAllocator = .init(makeBuffer(length: env.privateAllocatorSize, options: .storageModePrivate))

        renderStateResolver = .init(gpu: self)

        functions = .init(gpu: self)
        functions.build()

        frame = .init(gpu: self)
        frame.build(env: env.frame)
        
        taskQueue = .init(gpu: self)
        renderQueue = .init(gpu: self)
        renderQueue.build()
        
        _ = checkCounterSample()
        let counterSampleBuffer = makeCounterSampleBuffer(.timestamp, 32)
        if let counterSampleBuffer = counterSampleBuffer {
            counterSampler = GpuCounterSampler(
                counterSampleSummaryRepository: GpuCounterSampleSummaryRepository(),
                counterSampleReportRepository: GpuCounterSampleReportRepository()
            )
            counterSampler?.build(counterSampleBuffer: counterSampleBuffer)
        }
    }
}

// MARK: - Command Extensions
extension GpuContext {
    func doCommand<Result>(_ body: (_ commandBuffer: MTLCommandBuffer) throws -> Result) rethrows -> Result {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            appFatalError("failed to make command buffer.")
        }
        return try body(commandBuffer)
    }

    func makeCommandBuffer() -> MTLCommandBuffer {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            appFatalError("failed to make command buffer.")
        }
        return commandBuffer
    }
}

// MARK: - Buffer Creation Extensions
extension GpuContext {
    func makeBuffer(length: Int, options: MTLResourceOptions) -> MTLBuffer {
        guard let buffer = device.makeBuffer(length: length, options: options) else {
            appFatalError("failed to make buffer.")
        }
        return buffer
    }

    func makeTexture(_ descriptor: MTLTextureDescriptor) -> MTLTexture {
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            appFatalError("failed to make texture.")
        }
        return texture
    }
}

// MARK: - State Creation Extensions
extension GpuContext {
    func makeRenderPipelineState(_ descriptor: MTLRenderPipelineDescriptor) -> MTLRenderPipelineState {
        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            appFatalError("failed to make render pipeline state.", error: error)
        }
    }

    func makeDepthStancilState(_ descriptor: MTLDepthStencilDescriptor) -> MTLDepthStencilState {
        guard let depthStencilState = device.makeDepthStencilState(descriptor: descriptor) else {
            appFatalError("failed to make depth stencil state.")
        }
        return depthStencilState
    }

    func makeComputePipelineState(_ descriptor: MTLComputePipelineDescriptor) -> MTLComputePipelineState {
        do {
            return try device.makeComputePipelineState(descriptor: descriptor, options: .init(), reflection: nil)
        } catch {
            appFatalError("failed to make render pipeline state.", error: error)
        }
    }
}
