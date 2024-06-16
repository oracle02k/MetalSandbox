import MetalKit

struct Vertex {
    var position: float3
    var color: float4
    var texCoord: float2
}

final class Application {
    private let gpuContext: GpuContext
    private let renderObject: RenderObject

    private lazy var offscreenTexture: MTLTexture = uninitialized()
    private lazy var offscreenRenderPassDescriptor: MTLRenderPassDescriptor = uninitialized()
    private lazy var viewRenderPipelineState: MTLRenderPipelineState = uninitialized()
    private lazy var indexedPrimitives: IndexedPrimitives = uninitialized()
    private lazy var depthTexture: MTLTexture = uninitialized()

    init(_ gpuContext: GpuContext) {
        self.gpuContext = gpuContext
        self.renderObject = RenderObject(gpuContext)
    }

    func build() {
        depthTexture = {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2D
            descriptor.width = 320
            descriptor.height = 320
            descriptor.pixelFormat = .depth32Float
            descriptor.usage = [.renderTarget, .shaderRead]
            //descriptor.storageMode = .memoryless
            return gpuContext.makeTexture(descriptor)
        }()

        offscreenTexture = {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2D
            descriptor.width = 320
            descriptor.height = 320
            descriptor.pixelFormat = .bgra8Unorm
            descriptor.usage = [.renderTarget, .shaderRead]
            return gpuContext.makeTexture(descriptor)
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
            descriptor.depthAttachment.storeAction = .dontCare

            return descriptor
        }()

        viewRenderPipelineState = {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "View Render Pipeline"
            descriptor.sampleCount = 1
            descriptor.vertexFunction = gpuContext.findFunction(by: .TexcoordVertexFuction)
            descriptor.fragmentFunction = gpuContext.findFunction(by: .TexcoordFragmentFunction)
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            return gpuContext.makeRenderPipelineState(descriptor)
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

            let descriptor = IndexedPrimitiveDescriptor()
            descriptor.vertexBufferDescriptors = [vertextBufferDescriptor]
            descriptor.indexBufferDescriptor = indexBufferDescriptor
            descriptor.toporogy = .triangle

            return gpuContext.makeIndexedPrimitives(descriptor)
        }()

        renderObject.build()
    }

    func draw(viewDrawable: CAMetalDrawable, viewRenderPassDescriptor: MTLRenderPassDescriptor) {
        gpuContext.gpuDebugger.framInit()
        gpuContext.updateFrameDebug()
        

        let command = gpuContext.makeRenderCommand(offscreenRenderPassDescriptor)
        renderObject.draw(command)
        command.commit()

        viewRenderPassDescriptor.colorAttachments[0].clearColor = .init(red: 1, green: 1, blue: 0, alpha: 1)
        let viewCommand = gpuContext.makeRenderCommand(viewRenderPassDescriptor)
        viewCommand.useRenderPipelineState(viewRenderPipelineState)
        //viewCommand.setTexture(depthTexture, index: 0)
        viewCommand.setTexture(offscreenTexture, index: 0)
        viewCommand.drawIndexedPrimitives(indexedPrimitives)
        viewCommand.commit(with: viewDrawable)
    }
}
