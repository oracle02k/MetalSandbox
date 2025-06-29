import QuartzCore

final class DisplayLinkDriver {
    private let target: () -> Void
    private var displayLink: CADisplayLink?
    private let useMainRunLoop: Bool
    private var thread: Thread?
    
    init(useMainRunLoop: Bool = true, callback: @escaping () -> Void) {
        self.useMainRunLoop = useMainRunLoop
        self.target = callback
    }
    
    func start() {
        guard displayLink == nil else { return }
        
        if useMainRunLoop {
            setupDisplayLink(on: .main)
        } else {
            thread = Thread {
                self.setupDisplayLink(on: .current)
                RunLoop.current.run()
            }
            thread?.start()
        }
    }
    
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        thread = nil
    }
    
    func setPaused(_ paused: Bool) {
        displayLink?.isPaused = paused
    }
    
    private func setupDisplayLink(on runLoop: RunLoop) {
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = .init(
            minimum: Config.minFps,
            maximum: Config.maxFps,
            preferred: Config.preferredFps
        )
        link.add(to: runLoop, forMode: .default)
        self.displayLink = link
    }
    
    @objc private func tick() {
        target()
    }
}
