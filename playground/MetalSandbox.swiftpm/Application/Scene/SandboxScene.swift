import Foundation
import Metal

protocol SandboxScene{
    func build()
    func update()
    func changeSize(size: CGSize)
    func makeFrameRenderPassNodes(descriptor: MTLRenderPassDescriptor, pixelFormats: AttachmentPixelFormats) -> GpuPassNodeGroup
}
