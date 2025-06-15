import Metal
import simd

class RenderCommandDispatchParams{
    let commandBuffer: [RenderCommand]
    let tileShaderParams: TileShaderParams
    
    init(commandBuffer: [RenderCommand], tileShaderParams: TileShaderParams){
        self.commandBuffer = commandBuffer
        self.tileShaderParams = tileShaderParams
    }
}

class RenderCommandDispatcher {
    lazy var encoder:MTLRenderCommandEncoder = uninitialized()
    
    func dispatch(
        to commandBuffer:MTLCommandBuffer,
        descriptor:MTLRenderPassDescriptor,
        params: RenderCommandDispatchParams
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
