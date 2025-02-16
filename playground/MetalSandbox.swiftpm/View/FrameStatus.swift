import Foundation

class FrameDelta {
    let deltaTime: CFTimeInterval
    var microSecond: Float { Float(deltaTime) }
    var milliSecond: Float { Float(deltaTime) * 1000 }

    init(deltaTime: CFTimeInterval) {
        self.deltaTime = deltaTime
    }
}

class FrameStatus {
    let delta: FrameDelta
    let preferredFps: Float
    let actualFps: Float
    let displayLinkDuration: CFTimeInterval
    let frameCount: UInt64

    init(
        delta: FrameDelta,
        preferredFps: Float,
        actualFps: Float,
        displayLinkDuration: CFTimeInterval,
        frameCount: UInt64
    ) {
        self.delta = delta
        self.preferredFps = preferredFps
        self.actualFps = actualFps
        self.displayLinkDuration = displayLinkDuration
        self.frameCount = frameCount
    }
}
