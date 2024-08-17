import MetalKit

final class Application {
    enum Pipeline: String, CaseIterable {
        case TriangleRender
        case IndirectRender
        case TileRender
        case RogRender
    }

    private let gpu: GpuContext
    private var viewportSize: CGSize
    private var activePipeline: RenderPipeline? 

    init( gpu: GpuContext ) {
        self.gpu = gpu
        self.activePipeline = nil
        viewportSize = .init(width: 320, height: 320)
    }

    func build() {
        gpu.build()
        _ = gpu.checkCounterSample()
        
        changePipeline(pipeline: .TileRender)
    }
    
    func changePipeline(pipeline: Pipeline){
        activePipeline = switch pipeline {
        case .TriangleRender: DIContainer.resolve(TriangleRenderPipeline.self)
        case .IndirectRender: DIContainer.resolve(IndirectRenderPipeline.self)
        case .TileRender: DIContainer.resolve(TileRenderPipeline.self)
        case .RogRender: DIContainer.resolve(RasterOrderGroupRenderPipeline.self)
        }
        activePipeline?.build()
    }

    func changeViewportSize(_ size: CGSize) {
        viewportSize = size
        activePipeline?.changeSize(viewportSize: size)
    }

    func draw(to metalLayer: CAMetalLayer) {
        activePipeline?.draw(to: metalLayer)
    }
}
