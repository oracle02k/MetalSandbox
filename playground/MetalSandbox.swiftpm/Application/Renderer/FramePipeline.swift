import MetalKit

protocol FramePipeline {
    func changeSize(viewportSize: CGSize)
    func update(drawTo metalLayer: CAMetalLayer)
}
