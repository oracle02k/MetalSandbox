import Metal

class FrameStatsReport {
    let frameId: UInt64
    let frameStatus: FrameStatus
    let cpuUsage: Float
    let memory: KByte
    let vram: KByte
    let gpuTime: MilliSecond
    
    init(
        frameId: UInt64,
        frameStatus: FrameStatus,
        cpuUsage: Float,
        memory: KByte,
        vram: KByte,
        gpuTime: MilliSecond
    ) {
        self.frameId = frameId
        self.frameStatus = frameStatus
        self.cpuUsage = cpuUsage
        self.memory = memory
        self.vram = vram
        self.gpuTime = gpuTime
    }
}

class FrameStatsReporter {
    private let repository: FrameStatsReportRepository
    
    init(repository: FrameStatsReportRepository) {
        self.repository = repository
    }
    
    func report(
        frameStatus: FrameStatus,
        device: MTLDevice,
        gpuTime: MilliSecond
    ) {
        let report = FrameStatsReport(
            frameId: frameStatus.frameCount,
            frameStatus: frameStatus,
            cpuUsage: getCPUUsage(),
            memory: getMemoryUsed()!,
            vram: KByte(device.currentAllocatedSize / 1024),
            gpuTime: gpuTime
        )
        repository.persist(report)
    }
}
