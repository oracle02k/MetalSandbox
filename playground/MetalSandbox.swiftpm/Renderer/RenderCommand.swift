import MetalKit

class RenderCommand {
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

    func setTexture(_ texture: MTLTexture, index: Int) {
        commandEncoder.setFragmentTexture(texture, index: index)
    }

    func drawPrimitives(_ primitives: Primitives) {
        primitives.vertexBuffers.enumerated().forEach { index, buffer in
            commandEncoder.setVertexBuffer(buffer, offset: 0, index: index)
        }
        commandEncoder.drawPrimitives(type: primitives.toporogy, vertexStart: 0, vertexCount: primitives.vertexCount)
    }

    func drawIndexedPrimitives(_ primitives: IndexedPrimitives) {
        primitives.vertexBuffers.enumerated().forEach { index, buffer in
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
