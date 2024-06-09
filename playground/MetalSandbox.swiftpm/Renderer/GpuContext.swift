import MetalKit

class GpuContext {
    var gpuDebugger: GpuDebugger
    private let device: MTLDevice
    private let gpuFunctionContainer: GpuFunctionContainer
    private let renderPipelineStateContainer: RenderPipelineStateContainer
    private lazy var commandQueue: MTLCommandQueue = uninitialized()
    
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
    
    func build(){
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
    
    func makePrimitives(_ descriptor: PrimitivesDescriptor) -> Primitives {
        let buffers = descriptor.vertexBufferDescriptors.map { descriptor in
            descriptor.withUnsafeRawPointer(){
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
            descriptor.withUnsafeRawPointer(){
                device.makeBuffer(bytes: $0, length: descriptor.byteSize, options: [])!
            }
        }
        
        let indexBufferDescriptor = descriptor.indexBufferDescriptor
        let indexBuffer = indexBufferDescriptor.withUnsafeRawPointer() {
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
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            appFatalError("failed to make command buffer.")
        }
        guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            appFatalError("failed to make command encoder.")
        }
        return RenderCommand(device, commandBuffer, commandEncoder, gpuDebugger)
    }
    
    func findFunction(by name: GpuFunctionContainer.Name) -> MTLFunction {
        return gpuFunctionContainer.find(by: name)
    }
    
    func buildAndRegisterRenderPipelineState(from descriptor: MTLRenderPipelineDescriptor) -> Int {
        return renderPipelineStateContainer.buildAndRegister(from: descriptor)
    }
}
