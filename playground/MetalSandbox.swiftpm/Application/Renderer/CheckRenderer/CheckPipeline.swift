import MetalKit

class CheckPipeline: FramePipeline {
    private let gpu: GpuContext
    private let checkComputePass: CheckComputePass
    private let viewRenderPass: ViewRenderPass
    private var gpuCounterSampleGroup: GpuCounterSampleGroup?
    private var frameStatsReporter: FrameStatsReporter?

    init(gpu: GpuContext, checkComputePass: CheckComputePass, viewRenderPass: ViewRenderPass) {
        self.gpu = gpu
        self.checkComputePass = checkComputePass
        self.viewRenderPass = viewRenderPass
    }

    func build(
        with frameStatsReporter: FrameStatsReporter? = nil,
        and gpuCounterSampler: GpuCounterSampler? = nil
    ) {
        self.frameStatsReporter = frameStatsReporter
        gpuCounterSampleGroup = gpuCounterSampler?.makeGroup(groupLabel: "check pipeline")

        checkComputePass.build()
        viewRenderPass.build(with: gpuCounterSampleGroup)
        changeSize(viewportSize: .init(width: 320, height: 320))
    }

    func changeSize(viewportSize: CGSize) {
    }

    func update(
        frameStatus: FrameStatus,
        drawTo metalLayer: CAMetalLayer
    ) {
        gpu.doCommand { commandBuffer in
            checkComputePass.convert(commandBuffer)
            viewRenderPass.draw(to: metalLayer, using: commandBuffer, source: checkComputePass.outputTexture)
            commandBuffer.addCompletedHandler { [self] _ in
                frameStatsReporter?.report(frameStatus, gpu.device, [
                    .init("check pipeline", commandBuffer.gpuTime(), gpuCounterSampleGroup?.resolve())
                ])
            }
            commandBuffer.commit()
        }
    }
}
