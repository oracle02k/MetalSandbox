import MetalKit

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
                let pipeline = DIContainer.resolve(TrianglePipeline.self)
                pipeline.build(with: frameStatsReporter)
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
