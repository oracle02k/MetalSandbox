import Foundation

class FrameBuffer {
    let maxFramesInFlight = Config.maxFramesInFlight
    private(set) var frameIndex: Int = 0
    private(set) var frameNumber: Int = 0
    private lazy var inFlightSemaphore: DispatchSemaphore = uninitialized()

    func build() {
        inFlightSemaphore = DispatchSemaphore(value: maxFramesInFlight)
    }
    
    
    func waitForNextBufferIndex() -> Int {
        inFlightSemaphore.wait()
        frameIndex = frameNumber % maxFramesInFlight
        frameNumber += 1
        return  frameIndex
    }
    
    func releaseBufferIndex() {
        inFlightSemaphore.signal()
    }
}
