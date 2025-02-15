import MetalKit

class FrameStatsReport {
    let frameId: UInt64
    let frameStatus: FrameStatus
    let cpuUsage: Float
    let memory: KByte
    let vram: KByte

    init(
        frameId: UInt64,
        frameStatus: FrameStatus,
        cpuUsage: Float,
        memory: KByte,
        vram: KByte
    ) {
        self.frameId = frameId
        self.frameStatus = frameStatus
        self.cpuUsage = cpuUsage
        self.memory = memory
        self.vram = vram
    }
}

class FrameStatsReporter {
    private let repository: FrameStatsReportRepository

    init(repository: FrameStatsReportRepository) {
        self.repository = repository
    }

    func report(
        _ frameStatus: FrameStatus,
        _ device: MTLDevice
    ) {
        let report = FrameStatsReport(
            frameId: frameStatus.count,
            frameStatus: frameStatus,
            cpuUsage: getCPUUsage(),
            memory: getMemoryUsed()!,
            vram: KByte(device.currentAllocatedSize / 1024)
        )
        repository.persist(report)
    }
}
