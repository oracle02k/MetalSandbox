import SwiftUI

class ViewRenderPass {
    let screenRenderPass: ScreenRenderPass
    
    init(with screenRenderPass: ScreenRenderPass){
        self.screenRenderPass = screenRenderPass
    }
    
    func build(){
        screenRenderPass.build()
    }
    
    func draw(
        to metalLayer: CAMetalLayer,
        using commandBuffer: MTLCommandBuffer,
        source: MTLTexture
    ) {
        guard let drawable = metalLayer.nextDrawable() else {
            appFatalError("drawable error.")
        }
        
        let colorTarget = MTLRenderPassColorAttachmentDescriptor()
        colorTarget.texture = drawable.texture
        colorTarget.loadAction = .clear
        colorTarget.clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        colorTarget.storeAction = .store
        
        screenRenderPass.draw(toColor: colorTarget, using: commandBuffer, source: source)
        commandBuffer.present(drawable, afterMinimumDuration: 1.0/Double(Config.preferredFps))
    }
    
    func debugFrameStatus() {
        screenRenderPass.debugFrameStatus()
    }
}
