import MetalKit

protocol RenderPipeline {
    func build()
    func changeSize(viewportSize: CGSize)
    func draw(to metalLayer: CAMetalLayer)
}
