import MetalKit

class TrianglePipeline: FramePipeline {
    private let gpu: GpuContext
    private let triangleRenderPass: TriangleRenderPass
    private let viewRenderPass: ViewRenderPass
    private lazy var offscreenTexture: MTLTexture = uninitialized()

    init(gpu: GpuContext, triangleRenderPass: TriangleRenderPass, viewRenderPass: ViewRenderPass) {
        self.gpu = gpu
        self.triangleRenderPass = triangleRenderPass
        self.viewRenderPass = viewRenderPass
    }

    func build() {
        triangleRenderPass.build()
        viewRenderPass.build()
        changeSize(viewportSize: .init(width: 320, height: 320))
    }

    func changeSize(viewportSize: CGSize) {
        offscreenTexture = {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2D
            descriptor.width = Int(viewportSize.width)
            descriptor.height = Int(viewportSize.height)
            descriptor.pixelFormat = .bgra8Unorm
            descriptor.usage = [.renderTarget, .shaderRead]
            return gpu.makeTexture(descriptor)
        }()
    }

    func update(
        drawTo metalLayer: CAMetalLayer,
        logTo frameLogger: FrameStatisticsLogger?,
        _ frameComplited:@escaping ()->Void
    ) {
        let colorTarget = MTLRenderPassColorAttachmentDescriptor()
        colorTarget.texture = offscreenTexture
        colorTarget.loadAction = .clear
        colorTarget.clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        colorTarget.storeAction = .store

        gpu.doCommand { commandBuffer in
            triangleRenderPass.draw(toColor: colorTarget, using: commandBuffer)
            viewRenderPass.draw(to: metalLayer, using: commandBuffer, source: offscreenTexture)
            commandBuffer.addCompletedHandler { [self] _ in
                frameLogger?.addCommandBufferLog(.init(
                    label: "triangle pipeline",
                    commandBuffer: commandBuffer,
                    details: [
                        triangleRenderPass.debugFrameStatus(),
                        viewRenderPass.debugFrameStatus()
                    ]
                ))
                frameComplited()
            }
            commandBuffer.commit()
        }
    }
}
