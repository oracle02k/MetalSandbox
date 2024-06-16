import MetalKit

class GpuContext {
    var gpuDebugger: GpuDebugger
    private let device: MTLDevice
    private let gpuFunctionContainer: GpuFunctionContainer
    private let renderPipelineStateContainer: RenderPipelineStateContainer
    private lazy var commandQueue: MTLCommandQueue = uninitialized()
    private lazy var commandBuffer: MTLCommandBuffer = uninitialized()

    init(
        device: MTLDevice,
        gpuFunctionContainer: GpuFunctionContainer,
        renderPipelineStateContainer: RenderPipelineStateContainer,
        gpuDebugger: GpuDebugger
    ) {
        self.device = device
        self.gpuFunctionContainer = gpuFunctionContainer
        self.renderPipelineStateContainer = renderPipelineStateContainer
        self.gpuDebugger = gpuDebugger
    }

    func build() {
        commandQueue = {
            guard let commandQueue = device.makeCommandQueue() else {
                appFatalError("failed to make command queue.")
            }
            return commandQueue
        }()
    }

    func makeRenderPipelineState(_ descriptor: MTLRenderPipelineDescriptor) -> MTLRenderPipelineState {
        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            appFatalError("failed to make render pipeline state.")
        }
    }

    func makeDepthStancilState(_ descriptor: MTLDepthStencilDescriptor) -> MTLDepthStencilState {
        return device.makeDepthStencilState(descriptor: descriptor)!
    }

    func makePrimitives(_ descriptor: PrimitivesDescriptor) -> Primitives {
        let buffers = descriptor.vertexBufferDescriptors.map { descriptor in
            descriptor.withUnsafeRawPointer {
                device.makeBuffer(bytes: $0, length: descriptor.byteSize, options: [])!
            }
        }

        return Primitives(
            toporogy: descriptor.toporogy,
            vertexBuffers: buffers,
            vertexCount: descriptor.vertexCount
        )
    }

    func makeIndexedPrimitives(_ descriptor: IndexedPrimitiveDescriptor) -> IndexedPrimitives {
        let vertexBuffers = descriptor.vertexBufferDescriptors.map { descriptor in
            descriptor.withUnsafeRawPointer {
                device.makeBuffer(bytes: $0, length: descriptor.byteSize, options: [])!
            }
        }

        let indexBufferDescriptor = descriptor.indexBufferDescriptor
        let indexBuffer = indexBufferDescriptor.withUnsafeRawPointer {
            device.makeBuffer(bytes: $0, length: indexBufferDescriptor.byteSize, options: [])!
        }

        return IndexedPrimitives(
            toporogy: descriptor.toporogy,
            vertexBuffers: vertexBuffers,
            indexBuffer: indexBuffer,
            indexType: indexBufferDescriptor.indexType,
            indexCount: indexBufferDescriptor.count
        )
    }

    func makeTexture(_ descriptor: MTLTextureDescriptor) -> MTLTexture {
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            appFatalError("failed to make texture.")
        }
        return texture
    }
    
    func makeRenderCommand(_ renderPassDescriptor: MTLRenderPassDescriptor) -> RenderCommand {
        guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            appFatalError("failed to make render command encoder.")
        }
        return RenderCommand(device, commandBuffer, commandEncoder, gpuDebugger)
    }
    
    func makeComputeCommand(_ computePassDescriptor: MTLComputePassDescriptor) {
     //   let commandEncoder =  commandBuffer.makeComputeCommandEncoder(descriptor: computePassDescriptor) 
    }
     
    func doCommand<Result>(with drawable: CAMetalDrawable, _ body: () throws -> Result) rethrows -> Result {
        beginCommand()
        let result = try body()
        commitCommand(with: drawable)
        
        return result
    }
    
    func beginCommand() {
        commandBuffer = {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                appFatalError("failed to make command buffer.")
            }
            return commandBuffer
        }()
    }
    
    func commitCommand() {
        commandBuffer.addCompletedHandler { [self] commandBuffer in
            let start = commandBuffer.gpuStartTime
            let end = commandBuffer.gpuEndTime
            gpuDebugger.gpuTime = end - start
        }
        commandBuffer.commit()
    }
    
    func commitCommand(with drawable: CAMetalDrawable) {
        commandBuffer.present(drawable, afterMinimumDuration: 1.0/Double(30))
        commandBuffer.commit()
        
        gpuDebugger.viewWidth = drawable.texture.width
        gpuDebugger.viewHeight = drawable.texture.height
    }

    func findFunction(by name: GpuFunctionContainer.Name) -> MTLFunction {
        return gpuFunctionContainer.find(by: name)
    }

    func buildAndRegisterRenderPipelineState(from descriptor: MTLRenderPipelineDescriptor) -> Int {
        return renderPipelineStateContainer.buildAndRegister(from: descriptor)
    }
    
    func updateFrameDebug() {
        gpuDebugger.gpuAllocatedByteSize = device.currentAllocatedSize
    }
}
