import MetalKit

class IndirectPipeline: FramePipeline {
    private let gpu: GpuContext
    private let indirectRenderPass: IndirectRenderPass
    private let viewRenderPass: ViewRenderPass
    private let frameBuffer: FrameBuffer
    private lazy var offscreenTexture: MTLTexture = uninitialized()
    private lazy var depthTexture: MTLTexture = uninitialized()

    init(
        gpu: GpuContext,
        indirectRenderPass: IndirectRenderPass,
        viewRenderPass: ViewRenderPass,
        frameBuffer: FrameBuffer
    ) {
        self.gpu = gpu
        self.indirectRenderPass = indirectRenderPass
        self.viewRenderPass = viewRenderPass
        self.frameBuffer = frameBuffer
    }

    func build() {
        frameBuffer.build()
        indirectRenderPass.build(maxFramesInFlight: frameBuffer.maxFramesInFlight)
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

        depthTexture = {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2D
            descriptor.width = Int(viewportSize.width)
            descriptor.height = Int(viewportSize.height)
            descriptor.pixelFormat = .depth32Float
            descriptor.sampleCount = 1
            descriptor.usage = [.renderTarget, .shaderRead]
            // descriptor.storageMode = .memoryless
            return gpu.makeTexture(descriptor)
        }()
    }

    func update(
        drawTo metalLayer: CAMetalLayer, 
        logTo frameLogger: FrameStatisticsLogger?,
        _ frameComplited: @escaping ()->Void)
    {
        let colorTarget = MTLRenderPassColorAttachmentDescriptor()
        colorTarget.texture = offscreenTexture
        colorTarget.loadAction = .clear
        colorTarget.clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        colorTarget.storeAction = .store

        let depthTarget = MTLRenderPassDepthAttachmentDescriptor()
        depthTarget.texture = depthTexture
        depthTarget.loadAction = .clear
        depthTarget.clearDepth = 1.0
        depthTarget.storeAction = .dontCare

        let frameIndex = frameBuffer.waitForNextBufferIndex()
        Debug.frameLog("frame: \(frameBuffer.frameNumber)")

        indirectRenderPass.update()

        gpu.doCommand { commandBuffer in
            indirectRenderPass.preparaToDraw(using: commandBuffer, frameIndex: frameIndex)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }

        gpu.doCommand { commandBuffer in
            indirectRenderPass.draw(toColor: colorTarget, toDepth: depthTarget, using: commandBuffer, indirect: true)
            viewRenderPass.draw(to: metalLayer, using: commandBuffer, source: offscreenTexture)
            
            commandBuffer.addCompletedHandler { [self] _ in
                frameLogger?.addCommandBufferLog(.init(
                    label: "indirect pipeline",
                    commandBuffer: commandBuffer,
                    details: [
                        indirectRenderPass.debugFrameStatus(),
                        viewRenderPass.debugFrameStatus()
                    ]
                ))
                
                frameBuffer.releaseBufferIndex()
                frameComplited()
            }
            commandBuffer.commit()
        }
    }
}
