import SwiftUI
import MetalKit

enum AppError: Error {
    case MetalError
}
    
class MetalView: MTKView {
    
    let app: Application
    let renderer: Renderer
    let pipelineState: MTLRenderPipelineState
    
    init() {
        print("metal init")
        do {
            print("renderer init")
            renderer = System.shared.renderer
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = try renderer.makeFunction(name: "basic_vertex_function")
            pipelineDescriptor.fragmentFunction = try renderer.makeFunction(name: "basic_fragment_function")
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            print("piplineState init")
            pipelineState = try renderer.makePipelineState(pipelineDescriptor)
        }catch{
            appFatalError(error.localizedDescription)
        }
        
        print("application init")
        app = System.shared.app
        
        print("MTKView setup")
        super.init(frame: .zero, device: renderer.device)
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
        
        let renderCommand = renderer.drawBegin(renderPassDescriptor, pipelineState)
        app.draw(renderCommand)
        renderer.drawEnd(drawable, renderCommand)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
