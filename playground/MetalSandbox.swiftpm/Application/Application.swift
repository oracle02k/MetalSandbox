import MetalKit

struct Vertex {
    var position: simd_float3
    var color: simd_float4
    var texCoord: simd_float2
}

final class Application {
    private var viewportSize: CGSize
    private var gpu: GpuContext
    
    private let triangleRenderer: TriangleRenderer
    private let screenRenderer: ScreenRenderer
    private let addArrayCompute: AddArrayCompute
    private let indirectRenderer: IndirectRenderer

    private lazy var depthTexture: MTLTexture = uninitialized()
    private lazy var offscreenTexture: MTLTexture = uninitialized()
    private lazy var offscreenRenderPassDescriptor: MTLRenderPassDescriptor = uninitialized()

    init(
        gpu: GpuContext,
        indexedMeshFactory: IndexedMesh.Factory,
        meshFactory: Mesh.Factory
    ) {
        self.gpu = gpu
        
        self.screenRenderer = ScreenRenderer(
            gpu: gpu,
            indexedMeshFactory: indexedMeshFactory
        )

        self.triangleRenderer = TriangleRenderer(
            gpu: gpu,
            meshFactory: meshFactory
        )

        self.addArrayCompute = AddArrayCompute(gpu)
        self.indirectRenderer = IndirectRenderer(gpu)

        viewportSize = .init(width: 320, height: 320)
    }

    func build() {
        gpu.build()
        
        screenRenderer.build()
        triangleRenderer.build()
        addArrayCompute.build()
        indirectRenderer.build()

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

            return descriptor
        }()
    }

    func draw(viewDrawable: CAMetalDrawable, viewRenderPassDescriptor: MTLRenderPassDescriptor) {
        let viewport = MTLViewport(
            originX: 0,
            originY: 0,
            width: Double(viewportSize.width),
            height: Double(viewportSize.height),
            znear: 0.0,
            zfar: 1.0
        )

        Debug.frameLog("viewportSize: \(viewportSize.width), \(viewportSize.height)")
        /*
         commandQueue.doCommand { commandBuffer in
         indirectRenderer.draw(commandBuffer, renderPassDescriptor: viewRenderPassDescriptor)
         /*
         let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: viewRenderPassDescriptor)
         encoder?.endEncoding()
         */
         commandBuffer.present(viewDrawable, afterMinimumDuration: 1.0/Double(Config.preferredFps))
         commandBuffer.commit()
         }
         */

        /*
         commandQueue.doCommand { commandBuffer in
         guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
         appFatalError("failed to make compute command encoder.")
         }

         addArrayCompute.dispatch(encoder: encoder)
         encoder.endEncoding()

         commandBuffer.commit()
         commandBuffer.waitUntilCompleted()
         addArrayCompute.verifyResult()
         }
         */

        gpu.doCommand { commandBuffer in
            commandBuffer.addCompletedHandler {_ in
                let interval = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
                Debug.frameLog(String(format: "GpuTime: %.2fms", interval*1000))
                Debug.flush()
            }

            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: offscreenRenderPassDescriptor) else {
                appFatalError("failed to make render command encoder.")
            }
            encoder.setViewport(viewport)
            // triangleRenderer.draw(encoder)
            indirectRenderer.draw(encoder)
            encoder.endEncoding()

            viewRenderPassDescriptor.colorAttachments[0].clearColor = .init(red: 1, green: 1, blue: 0, alpha: 1)
            guard let viewEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: viewRenderPassDescriptor) else {
                appFatalError("failed to make render command encoder.")
            }
            viewEncoder.setViewport(viewport)
            screenRenderer.draw(viewEncoder, offscreenTexture: offscreenTexture)
            viewEncoder.endEncoding()

            commandBuffer.present(viewDrawable, afterMinimumDuration: 1.0/Double(Config.preferredFps))
            commandBuffer.commit()
        }
    }
}
