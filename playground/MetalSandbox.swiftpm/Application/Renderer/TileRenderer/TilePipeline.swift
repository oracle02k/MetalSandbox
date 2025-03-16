import MetalKit

class TilePipeline: FramePipeline {
    private let gpu: GpuContext
    private let tileRenderPass: TileRenderPass
    private let viewRenderPass: ViewRenderPass
    private let frameBuffer: FrameBuffer
    private lazy var offscreenTexture: MTLTexture = uninitialized()
    private lazy var depthTexture: MTLTexture = uninitialized()
    private var frameStatsReporter: FrameStatsReporter?

    init(
        gpu: GpuContext,
        tileRenderPass: TileRenderPass,
        viewRenderPass: ViewRenderPass,
        frameBuffer: FrameBuffer
    ) {
        self.gpu = gpu
        self.tileRenderPass = tileRenderPass
        self.viewRenderPass = viewRenderPass
        self.frameBuffer = frameBuffer
    }

    func build(
        with frameStatsReporter: FrameStatsReporter? = nil
    ) {
        self.frameStatsReporter = frameStatsReporter
        frameBuffer.build()
        tileRenderPass.build(maxFramesInFlight: frameBuffer.maxFramesInFlight)
        viewRenderPass.build()
        changeSize(viewportSize: .init(width: 320, height: 320))
    }

    func changeSize(viewportSize: CGSize) {
        tileRenderPass.changeSize(size: viewportSize)
        offscreenTexture = {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2D
            descriptor.width = Int(viewportSize.width)
            descriptor.height = Int(viewportSize.height)
            descriptor.pixelFormat = .bgra8Unorm
            descriptor.usage = [.renderTarget, .shaderRead]
            return gpu.makeTexture(descriptor)
        }()

        depthTexture = {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2D
            descriptor.width = Int(viewportSize.width)
            descriptor.height = Int(viewportSize.height)
            descriptor.pixelFormat = .depth32Float
            descriptor.sampleCount = 1
            descriptor.usage = [.renderTarget, .shaderRead]
            // descriptor.storageMode = .memoryless
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

        let depthTarget = MTLRenderPassDepthAttachmentDescriptor()
        depthTarget.texture = depthTexture
        depthTarget.loadAction = .clear
        depthTarget.clearDepth = 1.0
        depthTarget.storeAction = .dontCare

        let frameIndex = frameBuffer.waitForNextBufferIndex()
        print("frame: \(frameBuffer.frameNumber)")

        tileRenderPass.updateState(currentBufferIndex: frameIndex)

        gpu.doCommand { commandBuffer in
            tileRenderPass.draw(
                toColor: colorTarget,
                toDepth: depthTarget,
                using: commandBuffer,
                frameIndex: frameIndex,
                transparency: true
            )
            viewRenderPass.draw(to: metalLayer, using: commandBuffer, source: offscreenTexture)

            commandBuffer.addCompletedHandler { [self] _ in
                frameStatsReporter?.report(
                    frameStatus: frameStatus,
                    device: gpu.device,
                    gpuTime: commandBuffer.gpuTime()
                )
                frameBuffer.releaseBufferIndex()
            }
            commandBuffer.commit()
        }
    }
}
