import MetalKit

class TrianglePipeline: FramePipeline {
    class Option {
        let gpuCounterSampler: CounterSampler?
        let frameStatsReporter: FrameStatsReporter?
        
        init(
            frameStatsReporter: FrameStatsReporter? = nil,
            gpuCounterSampler: CounterSampler? = nil
        ){
            self.frameStatsReporter = frameStatsReporter
            self.gpuCounterSampler = gpuCounterSampler
        }
    }
    
    private let gpu: GpuContext
    private let triangleRenderPass: TriangleRenderPass
    private let viewRenderPass: ViewRenderPass
    private var option = Option()
    private lazy var offscreenTexture: MTLTexture = uninitialized()

    init(
        gpu: GpuContext,
        triangleRenderPass: TriangleRenderPass,
        viewRenderPass: ViewRenderPass
    ) {
        self.gpu = gpu
        self.triangleRenderPass = triangleRenderPass
        self.viewRenderPass = viewRenderPass
    }

    func build(with option:Option = Option()) {
        self.option = option
        triangleRenderPass.build()
        viewRenderPass.build()
        changeSize(viewportSize: .init(width: 320, height: 320))
        
        if let counterSampler = option.gpuCounterSampler {
            counterSampler.build(counterSampleBuffer: gpu.makeCounterSampleBuffer(.timestamp, 32)!)
            triangleRenderPass.attachCounterSampler(option.gpuCounterSampler)
        }
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
                option.frameStatsReporter?.report(
                    frameStatus: frameStatus, 
                    device: gpu.device, 
                    gpuTime:commandBuffer.gpuTime()
                )
                option.gpuCounterSampler?.resolve(frame: frameStatus.frameCount)
            }
            commandBuffer.commit()
        }
    }
}
