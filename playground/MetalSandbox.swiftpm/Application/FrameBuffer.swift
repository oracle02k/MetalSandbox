import Foundation

class FrameBuffer {
    let maxFramesInFlight = Config.maxFramesInFlight
    private(set) var frameIndex: Int = 0
    private(set) var frameNumber: Int = 0
    private lazy var inFlightSemaphore: DispatchSemaphore = uninitialized()

    func build() {
        inFlightSemaphore = DispatchSemaphore(value: maxFramesInFlight)
    }

    func refreshIndex() -> Int {
        inFlightSemaphore.wait()
        frameNumber += 1
        frameIndex = frameNumber % maxFramesInFlight
        return  frameIndex
    }

    func release() {
        inFlightSemaphore.signal()
    }
}
