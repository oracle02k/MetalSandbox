import Metal
import simd

class GpuRenderCommandDispatchParams{
    let commandBuffer: [GpuRenderCommand]
    let tileShaderParams: GpuTileShaderParams
    
    init(commandBuffer: [GpuRenderCommand], tileShaderParams: GpuTileShaderParams){
        self.commandBuffer = commandBuffer
        self.tileShaderParams = tileShaderParams
    }
}

class GpuRenderCommandDispatcher {
    lazy var encoder: MTLRenderCommandEncoder = uninitialized()
    
    func dispatch(
        to commandBuffer:MTLCommandBuffer,
        descriptor:MTLRenderPassDescriptor,
        params: GpuRenderCommandDispatchParams
    ) {
        let tileShaderParams = params.tileShaderParams
        
        if tileShaderParams.maxImageBlockSampleLength != 0 {
            descriptor.tileWidth = tileShaderParams.tileSize.width
            descriptor.tileHeight = tileShaderParams.tileSize.height
            descriptor.imageblockSampleLength = tileShaderParams.maxImageBlockSampleLength
        }
        
        encoder = commandBuffer.makeRenderCommandEncoderWithSafe(descriptor: descriptor)
        for command in params.commandBuffer {
            command.execute(self)
        }
        encoder.endEncoding()
    }
}
