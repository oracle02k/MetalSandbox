import SwiftUI

class MetalCommandQueue {
    let device: MTLDevice
    private lazy var commandQueue: MTLCommandQueue = uninitialized()

    init(_ device: MTLDevice) {
        self.device = device
    }

    func build() {
        commandQueue = {
            guard let commandQueue = device.makeCommandQueue() else {
                appFatalError("failed to make command queue.")
            }
            return commandQueue
        }()
    }

    func doCommand<Result>(_ body: (_ commandBuffer: MTLCommandBuffer) throws -> Result) rethrows -> Result {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            appFatalError("failed to make command buffer.")
        }
        return try body(commandBuffer)
    }

    func makeCommandBuffer() -> MTLCommandBuffer {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            appFatalError("failed to make command buffer.")
        }
        return commandBuffer
    }
}
