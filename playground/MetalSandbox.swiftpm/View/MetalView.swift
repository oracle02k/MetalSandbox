import SwiftUI
import MetalKit

class MetalView: MTKView {
    init() {
        super.init(frame: .zero, device: System.shared.device)
        preferredFramesPerSecond = 30
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0.1, green: 0.57, blue: 0.25, alpha: 1)
        delegate = self
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

        System.shared.app.draw(viewDrawable: drawable, viewRenderPassDescriptor: renderPassDescriptor)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
