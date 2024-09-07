import Foundation

struct FrameDelta {
    let deltaTime: CFTimeInterval
    var microSecond: Float { Float(deltaTime) }
    var milliSecond: Float { Float(deltaTime) * 1000 }
}

struct FrameStatus {
    let delta: FrameDelta
    let preferredFps: Float
    let actualFps: Float
    let displayLinkDuration: CFTimeInterval
}


