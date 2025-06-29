import SwiftUI

protocol AAPLViewDelegate {
    func drawableResize(size: CGSize)
    func renderToMetalLayer(metalLayer: CAMetalLayer, view: MetalView, frameStatus: FrameStatus)
}

class MetalView: UIView {
    private var displayLinkDriver: DisplayLinkDriver?
    private var paused: Bool = false
    private var previousTimestamp: CFTimeInterval = CACurrentMediaTime()
    private let delegate = MetalViewDelegate()
    var colorPixelFormat: MTLPixelFormat = .bgra8Unorm
    var depthStencilPixelFormat: MTLPixelFormat = .depth32Float
    var sampleCount = 1
    var frameCount = 0
    
    override class var layerClass: AnyClass {
        return CAMetalLayer.self
    }
    
    override func didMoveToWindow() {
        Logger.log("MetalView.didMoveToWindow begin.")
        super.didMoveToWindow()
        stopRenderLoop()
        
        if let metalLayer = layer as? CAMetalLayer, metalLayer.device == nil {
            metalLayer.device = DIContainer.resolve(MetalDeviceResolver.self).resolve()
        }
        
        displayLinkDriver = DisplayLinkDriver(useMainRunLoop: Config.mainThreadRender) { [weak self] in
            self?.render()
        }
        displayLinkDriver?.start()
        
        Logger.log("MetalView.didMoveToWindow done.")
    }
    
    private func render() {
        guard let metalLayer = layer as? CAMetalLayer else { return }
        
        let timestamp = CACurrentMediaTime()
        let delta = timestamp - previousTimestamp
        let fps = delta > 0 ? 1.0 / delta : 0
        
        let frameStatus = FrameStatus(
            delta: .init(deltaTime: delta),
            preferredFps: Config.preferredFps,
            actualFps: Float(fps),
            displayLinkDuration: 1.0 / Double(Config.preferredFps),
            frameCount: UInt64(frameCount)
        )
        
        delegate.renderToMetalLayer(metalLayer: metalLayer, view: self, frameStatus: frameStatus)
        
        frameCount += 1
        previousTimestamp = timestamp
    }
    
    func stopRenderLoop() {
        displayLinkDriver?.stop()
        displayLinkDriver = nil
    }
    
    func setPaused(_ paused: Bool) {
        self.paused = paused
        displayLinkDriver?.setPaused(paused)
    }
    
    func didEnterBackground(notification: NSNotification) {
        Logger.log("MetalView.didEnterBackground begin.")
        setPaused(true)
        Logger.log("MetalView.didEnterBackground end.")
    }
    
    func willEnterForeground(notification: NSNotification) {
        Logger.log("MetalView.willEnterForeground begin.")
        setPaused(false)
        Logger.log("MetalView.willEnterForeground end.")
    }
    
    func setContentScaleFactor(contentScaleFactor: CGFloat) {
        Logger.log("MetalView.setContentScaleFactor begin.")
        super.contentScaleFactor = contentScaleFactor
        resizeDrawable(scaleFactor: window?.screen.nativeScale ?? 1.0)
        Logger.log("MetalView.setContentScaleFactor done.")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        resizeDrawable(scaleFactor: window?.screen.nativeScale ?? 1.0)
    }
    
    override var frame: CGRect {
        didSet { resizeDrawable(scaleFactor: window?.screen.nativeScale ?? 1.0) }
    }
    
    override var bounds: CGRect {
        didSet { resizeDrawable(scaleFactor: window?.screen.nativeScale ?? 1.0) }
    }
    
    func resizeDrawable(scaleFactor: CGFloat) {
        var newSize = bounds.size
        newSize.width *= scaleFactor
        newSize.height *= scaleFactor
        
        if newSize.width <= 0 || newSize.height <= 0 {
            return
        }
        
        guard let metalLayer = layer as? CAMetalLayer else {
            appFatalError("metal layer error.")
        }
        
        if newSize == metalLayer.drawableSize {
            return
        }
        
        metalLayer.drawableSize = newSize
        delegate.drawableResize(size: newSize)
    }
}

class MetalViewDelegate: AAPLViewDelegate {
    func drawableResize(size: CGSize) {
        let app = DIContainer.resolve(Application.self)
        app.changeViewportSize(size)
    }
    
    func renderToMetalLayer(metalLayer: CAMetalLayer, view: MetalView, frameStatus: FrameStatus) {
        let app = DIContainer.resolve(Application.self)
        app.update(drawTo: metalLayer, frameStatus: frameStatus)
    }
}
