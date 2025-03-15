import MetalKit

final class Application {
    static let ColorPixelFormat: MTLPixelFormat = .bgra8Unorm
    let gpu: GpuContext
    let gpuCounterSampler: CounterSampler? = DIContainer.resolve(CounterSampler.self)
    let frameStatsReporter: FrameStatsReporter? = DIContainer.resolve(FrameStatsReporter.self)
    
    let basicRenderPassFunctions: BasicRenderPassConfigurator.Functions
    let basicRenderPipelineFactory: BasicRenderPassConfigurator.RenderPipelineFactory
    lazy var basicRenderCommandEncoderFactory: BasicRenderPassConfigurator.CommandEncoderFactory = uninitialized()
    lazy var basicRenderPassPipelines: BasicRenderPassConfigurator.RenderPipelines = uninitialized()
    
    
    init(gpu: GpuContext) {
        self.gpu = gpu
        
        basicRenderPassFunctions = .init(with: gpu)
        basicRenderPipelineFactory = .init()
    }
    
    func changeViewportSize(_ size: CGSize) {
    }
    
    func build() {
        gpu.build()
        _ = gpu.checkCounterSample()
        
        basicRenderPassFunctions.build()
        basicRenderPassPipelines = basicRenderPipelineFactory.build(with: gpu, functions: basicRenderPassFunctions)
        basicRenderCommandEncoderFactory = .init(using: basicRenderPassPipelines)
        
        if let gpuCounterSampler = gpuCounterSampler {
            gpuCounterSampler.build(counterSampleBuffer: gpu.makeCounterSampleBuffer(.timestamp, 32)!)
        }
    }
    
    func update(drawTo metalLayer: CAMetalLayer, frameStatus: FrameStatus) {
        metalLayer.pixelFormat = Self.ColorPixelFormat
        guard let drawable = metalLayer.nextDrawable() else {
            appFatalError("drawable error.")
        }
        
        let colorIndex = BasicRenderPassConfigurator.RenderTargets.Color.rawValue
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[colorIndex].texture = drawable.texture
        descriptor.colorAttachments[colorIndex].loadAction = .clear
        descriptor.colorAttachments[colorIndex].clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        descriptor.colorAttachments[colorIndex].storeAction = .store
        
        gpu.doCommand { commandBuffer in
            commandBuffer.addCompletedHandler { [self] _ in
                frameStatsReporter?.report(
                    frameStatus: frameStatus, 
                    device: gpu.device, 
                    gpuTime:commandBuffer.gpuTime()
                )
                gpuCounterSampler?.resolve(frame: frameStatus.frameCount)
            }
            
            let encoder = basicRenderCommandEncoderFactory.makeEncoder(
                from: descriptor, using: commandBuffer, counterSampler: gpuCounterSampler
            )
            encoder.use(TriangleRenderPipeline.self){ dispatcher in
                dispatcher.setViewport(.init(leftTop: .init(0, 0), rightBottom: .init(320, 320)))
                dispatcher.makeVerticies(gpu: gpu)
                dispatcher.dispatch()
            }
            
            encoder.endEncoding()
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
