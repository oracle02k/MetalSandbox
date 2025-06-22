import Metal

class GpuRenderCommandRepository {
    private(set) var commandBuffer = [GpuRenderCommand]()

    func append<T: GpuRenderCommand>(_ command: T) {
        commandBuffer.append(command)
    }

    func clear() {
        commandBuffer = [GpuRenderCommand]()
    }

    func currentBuffer() -> [GpuRenderCommand] {
        return commandBuffer
    }
}
