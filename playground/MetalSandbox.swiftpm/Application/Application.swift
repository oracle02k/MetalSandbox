import MetalKit

final class Application {
    enum Pipeline: String, CaseIterable {
        case TriangleRender
        case IndirectRender
        case TileRender
        case RogRender
        case LifegameCPU
        case LifegameGPU
    }

    private let gpu: GpuContext
    private let gpuCounterSampler: GpuCounterSampler
    private let frameStatsReporter: FrameStatsReporter
    private var viewportSize: CGSize
    private var activePipeline: FramePipeline?
    
    init(
        gpu: GpuContext,
        frameStatsReporter: FrameStatsReporter,
        gpuCounterSampler: GpuCounterSampler
    ) {
        self.gpu = gpu
        self.frameStatsReporter = frameStatsReporter
        self.gpuCounterSampler = gpuCounterSampler
        self.activePipeline = nil
        viewportSize = .init(width: 320, height: 320)
    }

    func build() {
        gpu.build()
        _ = gpu.checkCounterSample()
        gpuCounterSampler.build()
        changePipeline(pipeline: .TriangleRender)
    }

    func changePipeline(pipeline: Pipeline) {
        synchronized(self){
            activePipeline = switch pipeline {
            case .TriangleRender: {
                let pipeline = DIContainer.resolve(TrianglePipeline.self)
                pipeline.build(with: frameStatsReporter, and: gpuCounterSampler)
                return pipeline
            }()
            case .IndirectRender: {
                let pipeline = DIContainer.resolve(IndirectPipeline.self)
                pipeline.build()
                return pipeline
            }()
            case .TileRender: {
                let pipeline = DIContainer.resolve(TilePipeline.self)
                pipeline.build()
                return pipeline
            }()
            case .RogRender: {
                let pipeline = DIContainer.resolve(RasterOrderGroupPipeline.self)
                pipeline.build()
                return pipeline
            }()
            case .LifegameCPU: {
                let pipeline = DIContainer.resolve(LifegamePipeline.self)
                pipeline.build(width: 100, height: 100, useCompute: false)
                return pipeline
            }()
            case .LifegameGPU: {
                let pipeline = DIContainer.resolve(LifegamePipeline.self)
                pipeline.build(width: 1000, height: 1000, useCompute: true)
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
        synchronized(self){
            activePipeline?.update(frameStatus: frameStatus, drawTo: metalLayer)
        }
    }
}
