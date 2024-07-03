import SwiftUI

protocol AAPLViewDelegate {
    func drawableResize(size: CGSize)
    func renderToMetalLayer(metalLayer: CAMetalLayer)
}

class MetalView: UIView {
    private var paused: Bool = false
    private var displayLink: CADisplayLink?
    private var previousTimeStamp: CFTimeInterval = .zero
    private let delegate = MetalViewDelegate()

    override class var layerClass: AnyClass {
        return CAMetalLayer.self
    }

    override func didMoveToWindow() {
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
    }

    @objc func render(_ displayLink: CADisplayLink) {
        guard let metalLayer = layer as? CAMetalLayer else {
            appFatalError("metal layer error.")
        }
    
        let delta = displayLink.targetTimestamp - previousTimeStamp
        let actualFramesPerSecond = 1 / (displayLink.targetTimestamp - displayLink.timestamp)

        Debug.frameClear()
        Debug.frameLog(String(format: "DeltaTime: %.2fms", delta*1000))
        Debug.frameLog(String(format: "Duration: %.2fms", displayLink.duration*1000))
        Debug.frameLog(String(format: "actualFPS: %.2ffps", actualFramesPerSecond))
        
        synchronized(metalLayer) {
            delegate.renderToMetalLayer(metalLayer: metalLayer)
        }
        
        previousTimeStamp = displayLink.targetTimestamp
        Debug.flush()
    }

    func setPaused(pause: Bool) {
        paused = pause
        displayLink?.isPaused = paused
    }

    func setupCADisplayLinkForScreen(screen: UIScreen) {
        displayLink = screen.displayLink(withTarget: self, selector: #selector(Self.render(_:)))!
        displayLink?.preferredFrameRateRange = .init(
            minimum: Config.minFps,
            maximum: Config.maxFps,
            preferred: Config.preferredFps
        )
        displayLink?.isPaused = self.paused
        displayLink?.add(to: .current, forMode: .default)
    }

    func didEnterBackground(notification: NSNotification) {
        paused = true
    }

    func willEnterForeground(notification: NSNotification) {
        paused = false
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
    }
}

class MetalViewDelegate: AAPLViewDelegate {
    func drawableResize(size: CGSize) {
        System.shared.app.changeViewportSize(size)
    }

    func renderToMetalLayer(metalLayer: CAMetalLayer) {
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
