import MetalKit

protocol FramePipeline {
    func changeSize(viewportSize: CGSize)
    func update(frameStatus: FrameStatus, drawTo metalLayer: CAMetalLayer)
}
