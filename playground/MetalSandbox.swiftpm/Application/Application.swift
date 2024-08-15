import MetalKit

final class Application {
    enum Pipeline {
        case TriangleRender
        case IndirectRender
        case TileRender
        case MrtRender
    }

    private let gpu: GpuContext
    private let frameBuffer: FrameBuffer

    private var viewportSize: CGSize
    private let screenRenderPass: ScreenRenderPass
    private let addArrayCompute: AddArrayCompute
    private let indirectRenderPass: IndirectRenderPass
    private let tileRenderPass: TileRenderPass
    private let rasterOrderGroupRenderPass: RasterOrderGroupRenderPass
    private let triangleRenderPipeline: TriangleRenderPipeline

    private lazy var depthTexture: MTLTexture = uninitialized()
    private lazy var offscreenTexture: MTLTexture = uninitialized()
    private lazy var offscreenTexture2: MTLTexture = uninitialized()

    private var activePipeline = Pipeline.TriangleRender

    init(
        gpu: GpuContext,
        frameBuffer: FrameBuffer
    ) {
        self.gpu = gpu
        self.frameBuffer = frameBuffer
        self.screenRenderPass = ScreenRenderPass(
            with: gpu, 
            indexedMeshFactory: DIContainer.resolve(IndexedMesh.Factory.self)
        )
        self.addArrayCompute = AddArrayCompute(with: gpu)
        self.indirectRenderPass = IndirectRenderPass(with: gpu)
        self.tileRenderPass = TileRenderPass(with: gpu)
        self.rasterOrderGroupRenderPass = RasterOrderGroupRenderPass(
            with: gpu, 
            indexedMeshFactory: DIContainer.resolve(IndexedMesh.Factory.self)
        )
        self.triangleRenderPipeline = DIContainer.resolve(TriangleRenderPipeline.self)

        viewportSize = .init(width: 320, height: 320)
    }

    func build() {
        gpu.build()
        _ = gpu.checkCounterSample()
        frameBuffer.build()
        screenRenderPass.build()
        indirectRenderPass.build(maxFramesInFlight: frameBuffer.maxFramesInFlight)
        tileRenderPass.build(maxFramesInFlight: frameBuffer.maxFramesInFlight)
        rasterOrderGroupRenderPass.build()

        // addArrayCompute.build()
        triangleRenderPipeline.build()

        refreshRenderTextures()
    }

    func changeViewportSize(_ size: CGSize) {
        viewportSize = size
        refreshRenderTextures()
        triangleRenderPipeline.changeSize(viewportSize: size)
    }

    func refreshRenderTextures() {
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

    func draw(to metalLayer: CAMetalLayer) {
        switch activePipeline {
        case .TriangleRender: triangleRenderPipeline.draw(to: metalLayer)
        case .IndirectRender: drawIndirectRenderPipeline(to: metalLayer)
        case .TileRender: drawTileRenderPipeline(to: metalLayer)
        case .MrtRender: drawMrtRenderPipeline(to: metalLayer)
        }
    }

    func drawTileRenderPipeline(to metalLayer: CAMetalLayer) {
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
        Debug.frameLog("view: \(viewportSize)")

        tileRenderPass.changeSize(size: viewportSize)
        tileRenderPass.updateState(currentBufferIndex: frameIndex)

        gpu.doCommand { commandBuffer in
            commandBuffer.addCompletedHandler { [self] _ in
                debugGpuTime(from: commandBuffer)
                tileRenderPass.debugFrameStatus()
                screenRenderPass.debugFrameStatus()
                frameBuffer.releaseBufferIndex()
                Debug.flush()
            }

            tileRenderPass.draw(
                toColor: colorTarget,
                toDepth: depthTarget,
                using: commandBuffer,
                frameIndex: frameIndex,
                transparency: true
            )
            drawViewRenderPass(to: metalLayer, using: commandBuffer)
            commandBuffer.commit()
        }
    }

    func drawIndirectRenderPipeline(to metalLayer: CAMetalLayer) {
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
            commandBuffer.addCompletedHandler { [self] _ in
                debugGpuTime(from: commandBuffer)
                indirectRenderPass.debugFrameStatus()
                screenRenderPass.debugFrameStatus()
                frameBuffer.releaseBufferIndex()
                Debug.flush()
            }

            indirectRenderPass.draw(toColor: colorTarget, toDepth: depthTarget, using: commandBuffer, indirect: true)
            drawViewRenderPass(to: metalLayer, using: commandBuffer)
            commandBuffer.commit()
        }
    }
    
    func drawMrtRenderPipeline(to metalLayer: CAMetalLayer) {
                Debug.frameLog("view: \(viewportSize)")
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
            commandBuffer.addCompletedHandler { [self] _ in
                debugGpuTime(from: commandBuffer)
                rasterOrderGroupRenderPass.debugFrameStatus()
                screenRenderPass.debugFrameStatus()
                Debug.flush()
            }

            rasterOrderGroupRenderPass.draw(
                toColor: colorTarget, 
                write: offscreenTexture2,
                using: commandBuffer)
            drawViewRenderPass(to: metalLayer, using: commandBuffer)
            commandBuffer.commit()
        }
    }

    func drawViewRenderPass(to metalLayer: CAMetalLayer, using commandBuffer: MTLCommandBuffer) {
        guard let drawable = metalLayer.nextDrawable() else {
            appFatalError("drawable error.")
        }

        let colorTarget = MTLRenderPassColorAttachmentDescriptor()
        colorTarget.texture = drawable.texture
        colorTarget.loadAction = .clear
        colorTarget.clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        colorTarget.storeAction = .store

        screenRenderPass.draw(toColor: colorTarget, using: commandBuffer, source: offscreenTexture2)
        commandBuffer.present(drawable, afterMinimumDuration: 1.0/Double(Config.preferredFps))
    }

    func debugGpuTime(from commandBuffer: MTLCommandBuffer) {
        let interval = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
        Debug.frameLog(String(format: "GpuTime: %.2fms", interval*1000))
    }
}
