import SwiftUI

protocol AAPLViewDelegate {
    func drawableResize(size: CGSize)
    func renderToMetalLayer(metalLayer: CAMetalLayer, view: MetalView, frameStatus: FrameStatus)
}

class MetalView: UIView {
    private var paused: Bool = false
    private var displayLink: CADisplayLink?
    private var previousTimeStamp: CFTimeInterval = .zero
    private let delegate = MetalViewDelegate()
    var colorPixelFormat: MTLPixelFormat = .bgra8Unorm
    var depthStencilPixelFormat: MTLPixelFormat = .depth32Float
    var sampleCount = 1

    override class var layerClass: AnyClass {
        return CAMetalLayer.self
    }

    override func didMoveToWindow() {
        Logger.log("MetalView.didMoveToWindow begin.")
        super.didMoveToWindow()
        stopRenderLoop()
        if Config.mainThreadRender {
            setupCADisplayLinkForScreen(screen: window!.screen)
        } else {
            Thread.detachNewThread { [self] in
                setupCADisplayLinkForScreen(screen: window!.screen)
                RunLoop.current.run()
            }
        }
        Logger.log("MetalView.didMoveToWindow done.")
    }

    @objc func render(_ displayLink: CADisplayLink) {
        guard let metalLayer = layer as? CAMetalLayer else {
            appFatalError("metal layer error.")
        }

        let delta = displayLink.targetTimestamp - previousTimeStamp
        let actualFramesPerSecond = 1 / (displayLink.targetTimestamp - displayLink.timestamp)
        
        let frameStatus = FrameStatus(
            delta: .init(deltaTime: delta),
            preferredFps: Config.preferredFps,
            actualFps: Float(actualFramesPerSecond),
            displayLinkDuration: displayLink.duration
        )

        synchronized(metalLayer) {
            delegate.renderToMetalLayer(metalLayer: metalLayer, view: self, frameStatus: frameStatus)
        }

        previousTimeStamp = displayLink.targetTimestamp
    }

    func setPaused(pause: Bool) {
        paused = pause
        displayLink?.isPaused = paused
    }

    func setupCADisplayLinkForScreen(screen: UIScreen) {
        Logger.log("MetalView.setupCADisplayLinkForScreen begin.")
        displayLink = screen.displayLink(withTarget: self, selector: #selector(Self.render(_:)))!
        displayLink?.preferredFrameRateRange = .init(
            minimum: Config.minFps,
            maximum: Config.maxFps,
            preferred: Config.preferredFps
        )
        displayLink?.isPaused = self.paused
        displayLink?.add(to: .current, forMode: .default)
        Logger.log("MetalView.setupCADisplayLinkForScreen done.")
    }

    func didEnterBackground(notification: NSNotification) {
        Logger.log("MetalView.didEnterBackground begin.")
        paused = true
        Logger.log("MetalView.didEnterBackground end.")
    }

    func willEnterForeground(notification: NSNotification) {
        Logger.log("MetalView.willEnterForeground begin.")
        paused = false
        Logger.log("MetalView.willEnterForeground end.")
    }

    func stopRenderLoop() {
        displayLink?.invalidate()
    }

    func setContentScaleFactor(contentScaleFactor: CGFloat) {
        Logger.log("MetalView.setContentScaleFactor begin.")
        super.contentScaleFactor = contentScaleFactor
        resizeDrawable(scaleFactor: window!.screen.nativeScale)
        Logger.log("MetalView.setContentScaleFactor done.")
    }

    override func layoutSubviews() {
        Logger.log("MetalView.layoutSubviews begin.")
        super.layoutSubviews()
        resizeDrawable(scaleFactor: window!.screen.nativeScale)
        Logger.log("MetalView.layoutSubviews done.")
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
        Logger.log("MetalView.resizeDrawable begin.")
        var newSize = self.bounds.size
        newSize.width *= scaleFactor
        newSize.height *= scaleFactor

        if newSize.width <= 0 || newSize.width <= 0 {
            return
        }

        guard let metalLayer = layer as? CAMetalLayer else {
            appFatalError("metal layer error.")
        }

        if newSize.width == metalLayer.drawableSize.width &&
            newSize.height == metalLayer.drawableSize.height {
            return
        }

        synchronized(metalLayer) {
            metalLayer.drawableSize = newSize
            delegate.drawableResize(size: newSize)
        }
        Logger.log("MetalView.resizeDrawable done.")
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
