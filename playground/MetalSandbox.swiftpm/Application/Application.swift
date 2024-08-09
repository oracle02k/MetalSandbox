import MetalKit

final class Application {
    enum Pipeline {
        case TriangleRender
        case IndirectRender
        case TileRender
    }
    
    private let gpu: GpuContext
    private let frameBuffer: FrameBuffer

    private var viewportSize: CGSize
    private let triangleRenderer: TriangleRenderer
    private let screenRenderer: ScreenRenderer
    private let addArrayCompute: AddArrayCompute
    private let indirectRenderer: IndirectRenderer
    private let tileRenderer: TileRenderer

    private lazy var depthTexture: MTLTexture = uninitialized()
    private lazy var offscreenTexture: MTLTexture = uninitialized()
    
    private var activePipeline = Pipeline.TileRender

    init(
        gpu: GpuContext,
        frameBuffer: FrameBuffer,
        indexedMeshFactory: IndexedMesh.Factory,
        meshFactory: Mesh.Factory
    ) {
        self.gpu = gpu
        self.frameBuffer = frameBuffer
        self.screenRenderer = ScreenRenderer(gpu: gpu, indexedMeshFactory: indexedMeshFactory)
        self.triangleRenderer = TriangleRenderer(gpu)
        self.addArrayCompute = AddArrayCompute(gpu)
        self.indirectRenderer = IndirectRenderer(gpu)
        self.tileRenderer = TileRenderer(gpu)

        viewportSize = .init(width: 320, height: 320)
    }

    func build() {
        gpu.build()
        _ = gpu.checkCounterSample()
        frameBuffer.build()
        screenRenderer.build()
        triangleRenderer.build()
        indirectRenderer.build(maxFramesInFlight: frameBuffer.maxFramesInFlight)
        tileRenderer.build()
        //addArrayCompute.build()
        
        refreshRenderPass()
    }

    func changeViewportSize(_ size: CGSize) {
        viewportSize = size
        refreshRenderPass()
    }

    func refreshRenderPass() {
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
    }
    
    func draw(to metalLayer: CAMetalLayer) {
        switch(activePipeline){
        case .TriangleRender: drawTriangleRenderPipeline(to: metalLayer)
        case .IndirectRender: drawIndirectRenderPipeline(to: metalLayer)
        case .TileRender: drawTileRenderPipeline(to: metalLayer)
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
        
        tileRenderer.changeSize(size: viewportSize)
        tileRenderer.updateState(currentBufferIndex: frameIndex)
        
        gpu.doCommand { commandBuffer in
            commandBuffer.addCompletedHandler { [self] _ in 
                debugGpuTime(from: commandBuffer)
                tileRenderer.debugFrameStatus()
                screenRenderer.debugFrameStatus()
                frameBuffer.releaseBufferIndex()
                Debug.flush()
            }
            
            tileRenderer.draw(
                toColor: colorTarget, 
                toDepth: depthTarget, 
                using: commandBuffer, 
                frameIndex: frameIndex
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
        
        indirectRenderer.update()
        
        gpu.doCommand { commandBuffer in
            indirectRenderer.preparaToDraw(using: commandBuffer, frameIndex: frameIndex)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
        
        gpu.doCommand { commandBuffer in
            commandBuffer.addCompletedHandler { [self] _ in 
                debugGpuTime(from: commandBuffer)
                indirectRenderer.debugFrameStatus()
                screenRenderer.debugFrameStatus()
                frameBuffer.releaseBufferIndex()
                Debug.flush()
            }
            
            indirectRenderer.draw(toColor: colorTarget, toDepth: depthTarget, using: commandBuffer, indirect: true)
            drawViewRenderPass(to: metalLayer, using: commandBuffer)
            commandBuffer.commit()
        }
    }
    
    func drawTriangleRenderPipeline(to metalLayer: CAMetalLayer) {
        let colorTarget = MTLRenderPassColorAttachmentDescriptor()
        colorTarget.texture = offscreenTexture
        colorTarget.loadAction = .clear
        colorTarget.clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        colorTarget.storeAction = .store
        
        gpu.doCommand { commandBuffer in
            commandBuffer.addCompletedHandler { [self] _ in 
                debugGpuTime(from: commandBuffer)
                triangleRenderer.debugFrameStatus()
                screenRenderer.debugFrameStatus()
                Debug.flush()
            }
            
            triangleRenderer.draw(toColor: colorTarget, using: commandBuffer)
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
        
        screenRenderer.draw(toColor: colorTarget, using: commandBuffer, source: offscreenTexture)
        commandBuffer.present(drawable, afterMinimumDuration: 1.0/Double(Config.preferredFps))
    }
    
    func debugGpuTime(from commandBuffer: MTLCommandBuffer) {
        let interval = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
        Debug.frameLog(String(format: "GpuTime: %.2fms", interval*1000))
    }
}
