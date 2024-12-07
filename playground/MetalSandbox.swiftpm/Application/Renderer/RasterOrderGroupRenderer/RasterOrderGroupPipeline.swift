import MetalKit

class RasterOrderGroupPipeline: FramePipeline {
    private let gpu: GpuContext
    private let rasterOrderGroupRenderPass: RasterOrderGroupRenderPass
    private let viewRenderPass: ViewRenderPass
    private lazy var offscreenTexture: MTLTexture = uninitialized()
    private lazy var offscreenTexture2: MTLTexture = uninitialized()

    init(
        gpu: GpuContext,
        rasterOrderGroupRenderPass: RasterOrderGroupRenderPass,
        viewRenderPass: ViewRenderPass
    ) {
        self.gpu = gpu
        self.rasterOrderGroupRenderPass = rasterOrderGroupRenderPass
        self.viewRenderPass = viewRenderPass
    }

    func build() {
        rasterOrderGroupRenderPass.build()
        viewRenderPass.build()
        changeSize(viewportSize: .init(width: 760, height: 760))
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

        offscreenTexture2 = {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2D
            descriptor.width = Int(viewportSize.width)
            descriptor.height = Int(viewportSize.height)
            descriptor.pixelFormat = .bgra8Unorm
            descriptor.usage = [.shaderWrite, .shaderRead]
            return gpu.makeTexture(descriptor)
        }()
    }

    func update(
        frameStatus:FrameStatus,
        drawTo metalLayer: CAMetalLayer
    ) {
        let colorTarget = MTLRenderPassColorAttachmentDescriptor()
        colorTarget.texture = offscreenTexture
        colorTarget.loadAction = .clear
        colorTarget.clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        colorTarget.storeAction = .store

        let colorTarget2 = MTLRenderPassColorAttachmentDescriptor()
        colorTarget2.texture = offscreenTexture2
        colorTarget2.loadAction = .clear
        colorTarget2.clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        colorTarget2.storeAction = .store

        gpu.doCommand { commandBuffer in
            rasterOrderGroupRenderPass.draw(
                toColor: colorTarget,
                write: offscreenTexture2,
                using: commandBuffer
            )
            viewRenderPass.draw(to: metalLayer, using: commandBuffer, source: offscreenTexture2)
            
            commandBuffer.addCompletedHandler { _ in
            }
            commandBuffer.commit()
        }
    }
}
