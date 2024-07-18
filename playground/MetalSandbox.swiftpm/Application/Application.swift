import MetalKit

struct Vertex {
    var position: simd_float3
    var color: simd_float4
    var texCoord: simd_float2
}

final class Application {
    private let gpu: GpuContext
    private let frameBuffer: FrameBuffer

    private var viewportSize: CGSize
    private let triangleRenderer: TriangleRenderer
    private let screenRenderer: ScreenRenderer
    private let addArrayCompute: AddArrayCompute
    private let indirectRenderer: IndirectRenderer

    private lazy var depthTexture: MTLTexture = uninitialized()
    private lazy var offscreenTexture: MTLTexture = uninitialized()
    private lazy var offscreenRenderPassDescriptor: MTLRenderPassDescriptor = uninitialized()

    private lazy var counterSampleBuffer: MTLCounterSampleBuffer = uninitialized()

    init(
        gpu: GpuContext,
        frameBuffer: FrameBuffer,
        indexedMeshFactory: IndexedMesh.Factory,
        meshFactory: Mesh.Factory
    ) {
        self.gpu = gpu
        self.frameBuffer = frameBuffer
        self.screenRenderer = ScreenRenderer(gpu: gpu, indexedMeshFactory: indexedMeshFactory)
        self.triangleRenderer = TriangleRenderer(gpu: gpu, meshFactory: meshFactory)
        self.addArrayCompute = AddArrayCompute(gpu)
        self.indirectRenderer = IndirectRenderer(gpu)

        viewportSize = .init(width: 320, height: 320)
    }

    func build() {
        gpu.build()
        _ = gpu.checkCounterSample()
        frameBuffer.build()
        screenRenderer.build()
        triangleRenderer.build()
        addArrayCompute.build()
        indirectRenderer.build(maxFramesInFlight: frameBuffer.maxFramesInFlight)
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

        offscreenRenderPassDescriptor = {
            let descriptor = MTLRenderPassDescriptor()
            descriptor.colorAttachments[0].texture = offscreenTexture
            descriptor.colorAttachments[0].loadAction = .clear
            descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            descriptor.colorAttachments[0].storeAction = .store

            descriptor.depthAttachment.texture = depthTexture
            descriptor.depthAttachment.loadAction = .clear
            descriptor.depthAttachment.clearDepth = 0.5
            descriptor.depthAttachment.storeAction = .store

            guard let sampleAttachment = descriptor.sampleBufferAttachments[0] else {
                appFatalError("sample buffer error.")
            }

            guard let counterSampleBuffer = gpu.makeCounterSampleBuffer(MTLCommonCounterSet.timestamp) else {
                appFatalError("sample buffer error.")
            }

            self.counterSampleBuffer = counterSampleBuffer
            sampleAttachment.sampleBuffer = self.counterSampleBuffer
            sampleAttachment.startOfVertexSampleIndex = 0
            sampleAttachment.endOfVertexSampleIndex = 1
            sampleAttachment.startOfFragmentSampleIndex = 2
            sampleAttachment.endOfFragmentSampleIndex = 3

            return descriptor
        }()
    }
    
    func draw(viewDrawable: CAMetalDrawable, viewRenderPassDescriptor: MTLRenderPassDescriptor) {
    
        let frameIndex = frameBuffer.waitForNextBufferIndex()
        Debug.frameLog("frame: \(frameBuffer.frameNumber)")

        indirectRenderer.update()

        let viewport = MTLViewport(
            originX: 0,
            originY: 0,
            width: Double(viewportSize.width),
            height: Double(viewportSize.height),
            znear: 0.0,
            zfar: 1.0
        )
        Debug.frameLog("viewportSize: \(viewportSize.width), \(viewportSize.height)")

        gpu.doCommand { commandBuffer in
            let blitEncoder = commandBuffer.makeBlitCommandEncoderWithSafe()
            indirectRenderer.beforeDraw(blitEncoder, frameIndex: frameIndex)
            blitEncoder.endEncoding()

            let computeEncoder = commandBuffer.makeComputeCommandEncoderWithSafe()
            addArrayCompute.dispatch(encoder: computeEncoder)
            computeEncoder.endEncoding()

            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            addArrayCompute.verifyResult()
        }

        gpu.doCommand { commandBuffer in
            commandBuffer.addCompletedHandler { [self] _ in
                let interval = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
                Debug.frameLog(String(format: "GpuTime: %.2fms", interval*1000))

                guard let sampleData = try? counterSampleBuffer.resolveCounterRange(0..<6) else {
                    appFatalError("Device failed to create a counter sample buffer.")
                }

                sampleData.withUnsafeBytes { body in
                    let sample = body.bindMemory(to: MTLCounterResultTimestamp.self)
                    let vertexInterval = Float(sample[1].timestamp - sample[0].timestamp) / Float(NSEC_PER_MSEC)
                    let fragmentInterval = Float(sample[3].timestamp - sample[2].timestamp) / Float(NSEC_PER_MSEC)
                    Debug.frameLog(String(format: "VertexTime: %.2fms", vertexInterval))
                    Debug.frameLog(String(format: "FragmentTime: %.2fms", fragmentInterval))
                }

                Debug.flush()
                frameBuffer.releaseBufferIndex()
            }

            let encoder = commandBuffer.makeRenderCommandEncoderWithSafe(descriptor: offscreenRenderPassDescriptor)
            encoder.setViewport(viewport)
            triangleRenderer.draw(encoder)
            indirectRenderer.draw(encoder)
            encoder.endEncoding()

            viewRenderPassDescriptor.colorAttachments[0].clearColor = .init(red: 1, green: 1, blue: 0, alpha: 1)
            let viewEncoder = commandBuffer.makeRenderCommandEncoderWithSafe(descriptor: viewRenderPassDescriptor)
            viewEncoder.setViewport(viewport)
            screenRenderer.draw(viewEncoder, offscreenTexture: offscreenTexture)
            viewEncoder.endEncoding()

            commandBuffer.present(viewDrawable, afterMinimumDuration: 1.0/Double(Config.preferredFps))
            commandBuffer.commit()
        }
    }
}
