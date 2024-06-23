import MetalKit

struct Vertex {
    var position: float3
    var color: float4
    var texCoord: float2
}

final class Application {
    var viewportSize: CGSize
    
    private let triangleRenderer: TriangleRenderer
    private let screenRenderer: ScreenRenderer
    private let addArrayCompute: AddArrayCompute
    private let commandQueue: MetalCommandQueue
    private let resourceFactory: MetalResourceFactory
    private let pipelineStateFactory: MetalPipelineStateFactory

    private lazy var depthTexture: MTLTexture = uninitialized()
    private lazy var offscreenTexture: MTLTexture = uninitialized()
    private lazy var offscreenRenderPassDescriptor: MTLRenderPassDescriptor = uninitialized()

    init(
        commandQueue: MetalCommandQueue,
        pipelineStateFactory: MetalPipelineStateFactory,
        resourceFactory: MetalResourceFactory,
        indexedMeshFactory: IndexedMesh.Factory,
        meshFactory: Mesh.Factory
    ) {
        self.commandQueue = commandQueue
        self.resourceFactory = resourceFactory
        self.pipelineStateFactory = pipelineStateFactory

        self.screenRenderer = ScreenRenderer(
            pipelineStateFactory: pipelineStateFactory,
            indexedMeshFactory: indexedMeshFactory
        )

        self.triangleRenderer = TriangleRenderer(
            pipelineStateFactory: pipelineStateFactory,
            meshFactory: meshFactory
        )

        self.addArrayCompute = AddArrayCompute(
            pipelineStateFactory: pipelineStateFactory,
            resourceFactory: resourceFactory
        )
        
        viewportSize = .init(width: 320, height: 320)
    }

    func build() {
        commandQueue.build()
        pipelineStateFactory.build()

        depthTexture = {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2D
            descriptor.width = 320
            descriptor.height = 320
            descriptor.pixelFormat = .depth32Float
            descriptor.sampleCount = 1
            descriptor.usage = [.renderTarget, .shaderRead]
            // descriptor.storageMode = .memoryless
            return resourceFactory.makeTexture(descriptor)
        }()

        offscreenTexture = {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2D
            descriptor.width = 320
            descriptor.height = 320
            descriptor.pixelFormat = .bgra8Unorm
            descriptor.usage = [.renderTarget, .shaderRead]
            return resourceFactory.makeTexture(descriptor)
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

        screenRenderer.build()
        triangleRenderer.build()
        addArrayCompute.build()
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
        
        Debug.frameClear()
        Debug.frameLog("viewportSize: \(viewportSize.width), \(viewportSize.height)")
        
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

        commandQueue.doCommand { commandBuffer in
            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: offscreenRenderPassDescriptor) else {
                appFatalError("failed to make render command encoder.")
            }
            triangleRenderer.draw(encoder)
            encoder.endEncoding()

            viewRenderPassDescriptor.colorAttachments[0].clearColor = .init(red: 1, green: 1, blue: 0, alpha: 1)
            guard let viewEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: viewRenderPassDescriptor) else {
                appFatalError("failed to make render command encoder.")
            }
            viewEncoder.setViewport(viewport)
            screenRenderer.draw(viewEncoder, offscreenTexture: offscreenTexture)
            viewEncoder.endEncoding()

            commandBuffer.present(viewDrawable, afterMinimumDuration: 1.0/Double(30))
            commandBuffer.commit()
        }
    }
}
