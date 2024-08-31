import MetalKit

protocol RenderPipeline {
    func changeSize(viewportSize: CGSize)
    func draw(to metalLayer: CAMetalLayer)
}
