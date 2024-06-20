import MetalKit

struct Vertex {
    var position: float3
    var color: float4
    var texCoord: float2
}

final class Application {
    private let renderObject: RenderObject
    private let computeObject: ComputeObject
    private let commandQueue: MetalCommandQueue
    private let pipelineStateFactory: MetalPipelineStateFactory
    private let resourceFactory: MetalResourceFactory
    private let indexedPrimitivesFactory: IndexedPrimitives.Factory

    private lazy var offscreenTexture: MTLTexture = uninitialized()
    private lazy var offscreenRenderPassDescriptor: MTLRenderPassDescriptor = uninitialized()
    private lazy var viewRenderPipelineState: MTLRenderPipelineState = uninitialized()
    private lazy var indexedPrimitives: IndexedPrimitives = uninitialized()
    private lazy var depthTexture: MTLTexture = uninitialized()

    init(
        commandQueue: MetalCommandQueue,
        pipelineStateFactory: MetalPipelineStateFactory,
        resourceFactory: MetalResourceFactory,
        indexedPrimitivesFactory: IndexedPrimitives.Factory,
        primitivesFactory: Primitives.Factory
    ) {
        self.commandQueue = commandQueue
        self.pipelineStateFactory = pipelineStateFactory
        self.resourceFactory = resourceFactory
        self.indexedPrimitivesFactory = indexedPrimitivesFactory

        self.renderObject = RenderObject(
            pipelineStateFactory: pipelineStateFactory,
            primitivesFactory: primitivesFactory
        )

        self.computeObject = ComputeObject(
            pipelineStateFactory: pipelineStateFactory,
            resourceFactory: resourceFactory
        )
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
            //descriptor.storageMode = .memoryless
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

        viewRenderPipelineState = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "View Render Pipeline"
            descriptor.sampleCount = 1
            descriptor.vertexFunction = pipelineStateFactory.findFunction(by: .TexcoordVertexFuction)
            descriptor.fragmentFunction = pipelineStateFactory.findFunction(by: .TexcoordFragmentFunction)
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.depthAttachmentPixelFormat = .depth32Float
            return pipelineStateFactory.makeRenderPipelineState(descriptor)
        }()

        indexedPrimitives = {
            let vertextBufferDescriptor = VertexBufferDescriptor<Vertex>()
            vertextBufferDescriptor.content = [
                .init(position: float3(-1, 1, 0), color: float4(0, 0, 0, 1), texCoord: float2(0, 0)),
                .init(position: float3(-1, -1, 0), color: float4(0, 0, 0, 1), texCoord: float2(0, 1)),
                .init(position: float3(1, -1, 0), color: float4(0, 0, 0, 1), texCoord: float2(1, 1)),
                .init(position: float3(1, 1, 0), color: float4(0, 0, 0, 1), texCoord: float2(1, 0))
            ]

            let indexBufferDescriptor = IndexBufferU16Descriptor()
            indexBufferDescriptor.content = [0, 1, 2, 2, 3, 0]

            let descriptor = IndexedPrimitives.Descriptor()
            descriptor.vertexBufferDescriptors = [vertextBufferDescriptor]
            descriptor.indexBufferDescriptor = indexBufferDescriptor
            descriptor.toporogy = .triangle

            return indexedPrimitivesFactory.make(descriptor)
        }()

        renderObject.build()
        computeObject.build()
    }

    func draw(viewDrawable: CAMetalDrawable, viewRenderPassDescriptor: MTLRenderPassDescriptor) {
        System.shared.gpuDebugger.framInit()
        
        commandQueue.doCommand { commandBuffer in
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                appFatalError("failed to make compute command encoder.")
            }

            computeObject.dispatch(encoder: encoder)
            encoder.endEncoding()

            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }

        commandQueue.doCommand { commandBuffer in
            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: offscreenRenderPassDescriptor) else {
                appFatalError("failed to make render command encoder.")
            }
            renderObject.draw(encoder)
            encoder.endEncoding()

            viewRenderPassDescriptor.colorAttachments[0].clearColor = .init(red: 1, green: 1, blue: 0, alpha: 1)
            guard let viewEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: viewRenderPassDescriptor) else {
                appFatalError("failed to make render command encoder.")
            }
            viewEncoder.setRenderPipelineState(viewRenderPipelineState)
            // viewEncoder.setTexture(depthTexture, index: 0)
            viewEncoder.setFragmentTexture(offscreenTexture, index: 0)
            viewEncoder.drawIndexedMesh(indexedPrimitives)
            viewEncoder.endEncoding()

            commandBuffer.present(viewDrawable, afterMinimumDuration: 1.0/Double(30))
            commandBuffer.commit()
        }
    }
}
