import MetalKit

typealias float2 = SIMD2<Float>
typealias float3 = SIMD3<Float>
typealias float4 = SIMD4<Float>

struct Vertex {
    var position: float3
    var color: float4
    var texCoord: float2
}

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
        return RenderCommand(device, commandBuffer, commandEncoder, renderPipelineStateContainer, gpuDebugger)
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
    let renderPipelineStateContainer: RenderPipelineStateContainer
    var currentRenderPipelineStateId: Int
    
    init(
        _ device: MTLDevice,
        _ commandBuffer: MTLCommandBuffer, 
        _ commandEncoder: MTLRenderCommandEncoder,
        _ renderPipelineStateContainer: RenderPipelineStateContainer,
        _ gpuDebugger: GpuDebugger
    ) {
        self.device = device
        self.commandBuffer = commandBuffer
        self.commandEncoder = commandEncoder
        self.renderPipelineStateContainer = renderPipelineStateContainer
        self.gpuDebugger = gpuDebugger
        self.currentRenderPipelineStateId = -1
    }
    
    func useRenderPipelineState(id: Int) {
        if(id != currentRenderPipelineStateId) {
            let pso = renderPipelineStateContainer.find(by: id)
            commandEncoder.setRenderPipelineState(pso)
            currentRenderPipelineStateId = id
        }
    }
    
    func setTexture(_ texture: MTLTexture, index: Int){
        commandEncoder.setFragmentTexture(texture, index:index)
    }
    
    func drawTriangles(_ vertices: [Vertex]) {
        let vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<Vertex>.stride * vertices.count,
            options: []
        )!
        commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
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
