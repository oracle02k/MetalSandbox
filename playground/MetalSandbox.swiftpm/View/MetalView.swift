import SwiftUI
import MetalKit

enum AppError: Error {
    case MetalError
}
    
class MetalView: MTKView {
    let app: Application
    
    init() {
        app = System.shared.app
        
        print("MTKView setup")
        super.init(frame: .zero, device: System.shared.device)
        preferredFramesPerSecond = 30
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0.1, green: 0.57, blue: 0.25, alpha: 1)
        delegate = self
        
        print("MetalView init finish")
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension MetalView: MTKViewDelegate {
    
    func draw(in view: MTKView) {
        view.drawableSize = view.frame.size
        
        // Get the current drawable and descriptor
        guard
            let drawable = view.currentDrawable,
            let renderPassDescriptor = view.currentRenderPassDescriptor
        else {
            return
        }
        
        app.draw(viewDrawable: drawable, viewRenderPassDescriptor: renderPassDescriptor)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
