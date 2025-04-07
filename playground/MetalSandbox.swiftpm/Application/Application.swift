import MetalKit

final class Application {
    static let ColorPixelFormat: MTLPixelFormat = .bgra8Unorm
    let gpu: GpuContext
    let gpuCounterSampler: CounterSampler? = DIContainer.resolve(CounterSampler.self)
    let frameStatsReporter: FrameStatsReporter? = DIContainer.resolve(FrameStatsReporter.self)
    let functions: ShaderFunctions
    let renderPipelineStateBuilder: RenderPipelineStateBuilder
    let frameAllocator:GpuFrameAllocator
    let renderPass: RenderPass
    let drawableRenderPass: RenderPass
        
    lazy var offscreen: MTLTexture = uninitialized()

    init(gpu: GpuContext) {
        self.gpu = gpu
        
        functions = .init(with: gpu)
        renderPipelineStateBuilder = .init(gpu: gpu)
        frameAllocator = .init(gpu:gpu)
        
        renderPass = .init(
            frameAllocator: frameAllocator,
            renderCommandRepository: RenderCommandRepository(),
            renderPipelineStateBuilder: renderPipelineStateBuilder,
            functions: functions
        )
        
        drawableRenderPass = .init(
            frameAllocator: frameAllocator,
            renderCommandRepository: RenderCommandRepository(),
            renderPipelineStateBuilder: renderPipelineStateBuilder,
            functions: functions
        )
    }

    func changeViewportSize(_ size: CGSize) {
    }

    func build() {
        gpu.build()
        _ = gpu.checkCounterSample()
        
        functions.buildShaderFolder()
        
        if let gpuCounterSampler = gpuCounterSampler {
            gpuCounterSampler.build(counterSampleBuffer: gpu.makeCounterSampleBuffer(.timestamp, 32)!)
        }

        offscreen = {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2D
            descriptor.width = 320
            descriptor.height = 320
            descriptor.pixelFormat = .bgra8Unorm
            descriptor.usage = [.renderTarget, .shaderRead]
            return gpu.makeTexture(descriptor)
        }()
        
        frameAllocator.build(size: 1024 * 1024)
    }

    func update(drawTo metalLayer: CAMetalLayer, frameStatus: FrameStatus) {
        frameAllocator.nextFrame()
        renderPass.clear()
        drawableRenderPass.clear()
        
        renderPass.usingRenderCommandBuilder{ builder in
            builder.withRenderPipelineDescriptor{ d in
                d.colorAttachments[0].pixelFormat = .bgra8Unorm
            }
            
            for _ in 0..<1000 {
                let meshRenderer = TriangleRenderer(renderCommandBuilder: builder)
                meshRenderer.draw(vertices: [
                    .init(position: .init(160, 0, 0.0), color: .init(1, 0, 0, 1)),
                    .init(position: .init(0, 320, 0.0), color: .init(0, 1, 0, 1)),
                    .init(position: .init(320, 320, 0.0), color: .init(0, 0, 1, 1))
                ])
            }
        }
        
        drawableRenderPass.usingRenderCommandBuilder{ builder in
            builder.withRenderPipelineDescriptor{ d in
                d.colorAttachments[0].pixelFormat = .bgra8Unorm
            }
            
            let passthroughtRenderer = PassthroughtRenderer(renderCommandBuilder: builder)
            passthroughtRenderer.draw(offscreen)
        }
        
        metalLayer.pixelFormat = Self.ColorPixelFormat
        guard let drawable = metalLayer.nextDrawable() else {
            appFatalError("drawable error.")
        }

        let colorIndex = 0
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[colorIndex].texture = offscreen// drawable.texture
        descriptor.colorAttachments[colorIndex].loadAction = .clear
        descriptor.colorAttachments[colorIndex].clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        descriptor.colorAttachments[colorIndex].storeAction = .store

        gpu.doCommand { commandBuffer in
            commandBuffer.addCompletedHandler { [self] _ in
                frameStatsReporter?.report(
                    frameStatus: frameStatus,
                    device: gpu.device,
                    gpuTime: commandBuffer.gpuTime()
                )
                gpuCounterSampler?.resolve(frame: frameStatus.frameCount)
            }

            do {
                gpuCounterSampler?.attachToRenderPass(descriptor: descriptor, name: "applicationRenderPass")
                renderPass.dispatch(to: commandBuffer, using: descriptor)
            }
            
            do {
                descriptor.colorAttachments[colorIndex].texture = drawable.texture
                gpuCounterSampler?.attachToRenderPass(descriptor: descriptor, name: "drawableRenderPass")
                drawableRenderPass.dispatch(to: commandBuffer, using: descriptor)
            }

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
/*
 final class Application {
 enum Pipeline: String, CaseIterable {
 case TriangleRender
 case IndirectRender
 case TileRender
 case RogRender
 case LifegameCPU
 case LifegameGPU
 case Check
 }

 private let gpu: GpuContext
 private let frameStatsReporter: FrameStatsReporter
 private var viewportSize: CGSize
 private var activePipeline: FramePipeline?

 init(
 gpu: GpuContext,
 frameStatsReporter: FrameStatsReporter
 ) {
 self.gpu = gpu
 self.frameStatsReporter = frameStatsReporter
 self.activePipeline = nil
 viewportSize = .init(width: 320, height: 320)
 }

 func build() {
 gpu.build()
 _ = gpu.checkCounterSample()
 changePipeline(pipeline: .TriangleRender)
 }

 func changePipeline(pipeline: Pipeline) {
 synchronized(self) {
 activePipeline = switch pipeline {
 case .TriangleRender: {
 let option = TrianglePipeline.Option(
 frameStatsReporter: frameStatsReporter,
 gpuCounterSampler: DIContainer.resolve(CounterSampler.self)
 )
 let pipeline = DIContainer.resolve(TrianglePipeline.self)
 pipeline.build(with: option)
 return pipeline
 }()
 case .IndirectRender: {
 let pipeline = DIContainer.resolve(IndirectPipeline.self)
 pipeline.build(with: frameStatsReporter)
 return pipeline
 }()
 case .TileRender: {
 let pipeline = DIContainer.resolve(TilePipeline.self)
 pipeline.build(with: frameStatsReporter)
 return pipeline
 }()
 case .RogRender: {
 let pipeline = DIContainer.resolve(RasterOrderGroupPipeline.self)
 pipeline.build(with: frameStatsReporter)
 return pipeline
 }()
 case .LifegameCPU: {
 let pipeline = DIContainer.resolve(LifegamePipeline.self)
 pipeline.build(width: 200, height: 200, useCompute: false, with: frameStatsReporter)
 return pipeline
 }()
 case .LifegameGPU: {
 let pipeline = DIContainer.resolve(LifegamePipeline.self)
 pipeline.build(width: 1000, height: 1000, useCompute: true, with: frameStatsReporter)
 return pipeline
 }()
 case .Check: {
 let pipeline = DIContainer.resolve(CheckPipeline.self)
 pipeline.build(with: frameStatsReporter)
 return pipeline
 }()
 }
 }
 }

 func changeViewportSize(_ size: CGSize) {
 viewportSize = size
 activePipeline?.changeSize(viewportSize: size)
 }

 func update(drawTo metalLayer: CAMetalLayer, frameStatus: FrameStatus) {
 synchronized(self) {
 activePipeline?.update(frameStatus: frameStatus, drawTo: metalLayer)
 }
 }
 }
 */
