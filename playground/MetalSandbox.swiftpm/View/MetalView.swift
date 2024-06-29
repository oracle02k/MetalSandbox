import SwiftUI

protocol AAPLViewDelegate {
    func drawableResize(size: CGSize)
    func renderToMetalLayer(metalLayer: CAMetalLayer)
}

class MetalView : UIView {
    private var paused: Bool = false
    private var displayLink: CADisplayLink?
    private let delegate: AAPLViewDelegate = RenderViewDelegate()
    
    override class var layerClass: AnyClass {
        return CAMetalLayer.self
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        setupCADisplayLinkForScreen(screen: window!.screen)
        displayLink?.add(to: RunLoop.current, forMode: .common)
    }
    
    @objc func render() {
        guard let metalLayer = layer as? CAMetalLayer else {
            appFatalError("metal layer error.")
        }
        
        delegate.renderToMetalLayer(metalLayer: metalLayer)
    }
    
    func setPaused(pause: Bool) {
        paused = pause;
        displayLink?.isPaused = paused;
    }
    
    func setupCADisplayLinkForScreen(screen: UIScreen) {
        stopRenderLoop()
        displayLink = screen.displayLink(withTarget: self, selector: #selector(Self.render))!
        displayLink?.isPaused = self.paused;
        displayLink?.preferredFramesPerSecond = 30;
    }
    
    func didEnterBackground(notification: NSNotification) {
        paused = true;
    }
    
    func willEnterForeground(notification: NSNotification) {
        paused = false;
    }
    
    func stopRenderLoop() {
        displayLink?.invalidate()
    }
    
    func setContentScaleFactor(contentScaleFactor: CGFloat) {
        super.contentScaleFactor = contentScaleFactor
        resizeDrawable(scaleFactor: window!.screen.nativeScale)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        resizeDrawable(scaleFactor: window!.screen.nativeScale)
    }
    
    override var frame: CGRect {
        get { super.frame}
        set {
            super.frame = newValue
            guard let window = self.window else {
                return
            }
            resizeDrawable(scaleFactor: window.screen.nativeScale)    
        }
    }
    
    override var bounds: CGRect {
        get { super.bounds}
        set {
            super.bounds = newValue
            guard let window = self.window else {
                return
            }
            resizeDrawable(scaleFactor: window.screen.nativeScale)
        }
    }
    
    func resizeDrawable(scaleFactor: CGFloat) {
        var newSize = self.bounds.size
        newSize.width *= scaleFactor
        newSize.height *= scaleFactor
        
        if(newSize.width <= 0 || newSize.width <= 0) {
            return
        }
        
        guard let metalLayer = layer as? CAMetalLayer else {
            appFatalError("metal layer error.")
        }
        
        if(newSize.width == metalLayer.drawableSize.width &&
           newSize.height == metalLayer.drawableSize.height) {
            return
        }
        
        metalLayer.drawableSize = newSize
        delegate.drawableResize(size: newSize)
    }
}
    

class RenderViewDelegate : AAPLViewDelegate {
    func drawableResize(size: CGSize){
        System.shared.app.changeViewportSize(size)
    }
    
    func renderToMetalLayer(metalLayer: CAMetalLayer){
        metalLayer.pixelFormat = .bgra8Unorm
        guard let drawable = metalLayer.nextDrawable() else {
            appFatalError("drawable error.")
        }
        
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = drawable.texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.1, green: 0.57, blue: 0.25, alpha: 1)
        descriptor.colorAttachments[0].storeAction = .store
        
        System.shared.app.draw(viewDrawable: drawable, viewRenderPassDescriptor: descriptor)
    }
}
