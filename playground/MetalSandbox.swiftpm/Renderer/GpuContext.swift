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

class RenderCommand
{
    let device: MTLDevice
    var gpuDebugger: GpuDebugger
    let commandBuffer: MTLCommandBuffer
    let commandEncoder: MTLRenderCommandEncoder
    var currentRenderPipelineState: MTLRenderPipelineState?
    
    init(
        _ device: MTLDevice,
        _ commandBuffer: MTLCommandBuffer, 
        _ commandEncoder: MTLRenderCommandEncoder,
        _ gpuDebugger: GpuDebugger
    ) {
        self.device = device
        self.commandBuffer = commandBuffer
        self.commandEncoder = commandEncoder
        self.gpuDebugger = gpuDebugger
        self.currentRenderPipelineState = nil
    }
    
    func useRenderPipelineState(_ renderPipelineState: MTLRenderPipelineState) {
        guard renderPipelineState !== currentRenderPipelineState else { return }
        commandEncoder.setRenderPipelineState(renderPipelineState)
        currentRenderPipelineState = renderPipelineState
    }
    
    func setTexture(_ texture: MTLTexture, index: Int){
        commandEncoder.setFragmentTexture(texture, index:index)
    }
    
    func drawPrimitives(_ primitives: Primitives) {
        primitives.vertexBuffers.enumerated().forEach() { index, buffer in
            commandEncoder.setVertexBuffer(buffer, offset: 0, index: index)
        }
        commandEncoder.drawPrimitives(type: primitives.toporogy, vertexStart: 0, vertexCount: primitives.vertexCount)
    }
    
    func drawIndexedPrimitives(_ primitives: IndexedPrimitives) {
        primitives.vertexBuffers.enumerated().forEach() { index, buffer in
            commandEncoder.setVertexBuffer(buffer, offset: 0, index: index)
        }
        commandEncoder.drawIndexedPrimitives(
            type: primitives.toporogy,
            indexCount: primitives.indexCount, 
            indexType: primitives.indexType,
            indexBuffer: primitives.indexBuffer,
            indexBufferOffset: 0
        )
    }
    
    func commit() {
        commandEncoder.endEncoding()
        commandBuffer.addCompletedHandler { [self] commandBuffer in
            let start = commandBuffer.gpuStartTime
            let end = commandBuffer.gpuEndTime
            gpuDebugger.gpuTime = end - start
        }
        commandBuffer.commit()
    }
    
    func commit(with drawable: CAMetalDrawable) {
        commandEncoder.endEncoding()
        commandBuffer.present(drawable, afterMinimumDuration: 1.0/Double(30))
        commandBuffer.commit()
        
        gpuDebugger.viewWidth = drawable.texture.width
        gpuDebugger.viewHeight = drawable.texture.height
    }
}
