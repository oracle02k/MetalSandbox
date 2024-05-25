import MetalKit

typealias float2 = SIMD2<Float>
typealias float3 = SIMD3<Float>
typealias float4 = SIMD4<Float>

struct Vertex {
    var position: float3
    var color: float4
    var texCoord: float2
}

class Renderer {
    let device: MTLDevice
    let library: MTLLibrary
    let commandQueue: MTLCommandQueue
    var debugger: RendererDebugger
    
    init(_ debugger: RendererDebugger) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            appFatalError("GPU not available")
        }
        
        self.device = device
        self.commandQueue = self.device.makeCommandQueue()!
        self.library = try device.makeLibrary(source: shader, options: nil)
        self.debugger = debugger
    }
    
    func makeFunction(name: String) throws -> MTLFunction {
        guard let function = library.makeFunction(name: name) else {
            throw AppError.MetalError
        }
        return function
    }
    
    func makePipelineState(_ descriptor: MTLRenderPipelineDescriptor) throws -> MTLRenderPipelineState {
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    func makeTexture(_ descriptor: MTLTextureDescriptor) -> MTLTexture {
        return device.makeTexture(descriptor: descriptor)!
    }
    
    func makeRenderCommand(
        _ renderPassDescriptor: MTLRenderPassDescriptor, 
        _ renderPilelineState: MTLRenderPipelineState
    ) -> RenderCommand {
        // Create a buffer from the commandQueue
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        commandEncoder.setRenderPipelineState(renderPilelineState)
        
        return RenderCommand(device, commandBuffer, commandEncoder, debugger)
    }
}

class RenderCommand
{
    let device: MTLDevice
    let commandBuffer: MTLCommandBuffer
    let commandEncoder: MTLRenderCommandEncoder
    var debugger: RendererDebugger
    
    init(
        _ device: MTLDevice,
        _ commandBuffer: MTLCommandBuffer, 
        _ commandEncoder: MTLRenderCommandEncoder,
        _ debugger: RendererDebugger
    ) {
        self.device = device
        self.commandBuffer = commandBuffer
        self.commandEncoder = commandEncoder
        self.debugger = debugger
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
            debugger.gpuTime = end - start
        }
        commandBuffer.commit()
    }
    
    func commit(with drawable: CAMetalDrawable) {
        commandEncoder.endEncoding()
        commandBuffer.present(drawable, afterMinimumDuration: 1.0/Double(30))
        commandBuffer.addCompletedHandler { [self] commandBuffer in
            let start = commandBuffer.gpuStartTime
            let end = commandBuffer.gpuEndTime
            debugger.gpuTime = end - start
        }
        commandBuffer.commit()
        
        debugger.viewWidth = drawable.texture.width
        debugger.viewHeight = drawable.texture.height
    }
}
