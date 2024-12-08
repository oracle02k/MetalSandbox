import MetalKit

class TrianglePipeline: FramePipeline {
    private let gpu: GpuContext
    private let triangleRenderPass: TriangleRenderPass
    private let viewRenderPass: ViewRenderPass
    private lazy var offscreenTexture: MTLTexture = uninitialized()
    private var gpuCounterSampleGroup: GpuCounterSampleGroup?
    private var frameStatsReporter: FrameStatsReporter?

    init(gpu: GpuContext, triangleRenderPass: TriangleRenderPass, viewRenderPass: ViewRenderPass) {
        self.gpu = gpu
        self.triangleRenderPass = triangleRenderPass
        self.viewRenderPass = viewRenderPass
    }

    func build(
        with frameStatsReporter: FrameStatsReporter? = nil,
        and gpuCounterSampler: GpuCounterSampler? = nil
    ) {
        self.frameStatsReporter = frameStatsReporter
        gpuCounterSampleGroup = gpuCounterSampler?.makeGroup(groupLabel: "triangle pipeline")
        triangleRenderPass.build(with: gpuCounterSampleGroup)
        // viewRenderPass.build(with: gpuCounterSampleGroup)
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
                frameStatsReporter?.report(frameStatus, gpu.device, [
                    .init("triangle pipeline", commandBuffer.gpuTime(), gpuCounterSampleGroup?.resolve())
                ])
            }
            commandBuffer.commit()
        }
    }
}
