import MetalKit

class TrianglePipeline: FramePipeline {
    private let gpu: GpuContext
    private let triangleRenderPass: TriangleRenderPass
    private let viewRenderPass: ViewRenderPass
    private let gpuCounterSampler: CounterSampler
    private lazy var offscreenTexture: MTLTexture = uninitialized()
    private var frameStatsReporter: FrameStatsReporter?

    init(
        gpu: GpuContext,
        triangleRenderPass: TriangleRenderPass,
        viewRenderPass: ViewRenderPass,
        gpuCounterSampler: CounterSampler
    ) {
        self.gpu = gpu
        self.triangleRenderPass = triangleRenderPass
        self.viewRenderPass = viewRenderPass
        self.gpuCounterSampler = gpuCounterSampler
    }

    func build(
        with frameStatsReporter: FrameStatsReporter? = nil
    ) {
        self.frameStatsReporter = frameStatsReporter
        let counterSampleBuffer = gpu.makeCounterSampleBuffer(.timestamp, 32)!
        gpuCounterSampler.build(counterSampleBuffer: counterSampleBuffer)
        
        triangleRenderPass.build()
        triangleRenderPass.attachCounterSampler(gpuCounterSampler)
        
        viewRenderPass.build()
        changeSize(viewportSize: .init(width: 320, height: 320))
    }

    func changeSize(viewportSize: CGSize) {
        offscreenTexture = {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2D
            descriptor.width = Int(viewportSize.width)
            descriptor.height = Int(viewportSize.height)
            descriptor.pixelFormat = .bgra8Unorm
            descriptor.usage = [.renderTarget, .shaderRead]
            return gpu.makeTexture(descriptor)
        }()
    }

    func update(
        frameStatus: FrameStatus,
        drawTo metalLayer: CAMetalLayer
    ) {
        let colorTarget = MTLRenderPassColorAttachmentDescriptor()
        colorTarget.texture = offscreenTexture
        colorTarget.loadAction = .clear
        colorTarget.clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        colorTarget.storeAction = .store

        gpu.doCommand { commandBuffer in
            triangleRenderPass.draw(toColor: colorTarget, using: commandBuffer)
            viewRenderPass.draw(to: metalLayer, using: commandBuffer, source: offscreenTexture)
            commandBuffer.addCompletedHandler { [self] _ in
                frameStatsReporter?.report(frameStatus, gpu.device)
                gpuCounterSampler.resolve(frame: frameStatus.count)
            }
            commandBuffer.commit()
        }
    }
}
