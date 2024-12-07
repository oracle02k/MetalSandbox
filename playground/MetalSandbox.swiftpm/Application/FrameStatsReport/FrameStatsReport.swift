import MetalKit

class FrameStatsReport {
    let frameId: UInt64
    let frameStatus: FrameStatus
    let cpuUsage:Float
    let memory: KByte
    let vram: KByte
    let commandBufferReports: [CommandBufferReport]
    
    init(
        frameId: UInt64,
        frameStatus: FrameStatus,
        cpuUsage:Float,
        memory: KByte,
        vram: KByte,
        commandBufferReports: [CommandBufferReport]
    ){
        self.frameId = frameId
        self.frameStatus = frameStatus
        self.cpuUsage = cpuUsage
        self.memory = memory
        self.vram = vram
        self.commandBufferReports = commandBufferReports
    }
}

class CommandBufferReport {
    let label: String
    let gpuTime: MilliSecond
    let counterSampleReports: [GpuCounterSampleReport]?
    
    init(
        _ label: String,
        _ gpuTime: MilliSecond,
        _ counterSampleReports: [GpuCounterSampleReport]?
    ){
        self.label = label
        self.gpuTime = gpuTime
        self.counterSampleReports = counterSampleReports
    }
}

class FrameStatsReporter {
    private let repository: FrameStatsReportRepository
    
    init(repository: FrameStatsReportRepository){
        self.repository = repository    
    }
    
    func report(
        _ frameStatus: FrameStatus, 
        _ device: MTLDevice, 
        _ commandBufferReports:[CommandBufferReport]
    ) {
        let report = FrameStatsReport(
            frameId: frameStatus.count,
            frameStatus: frameStatus,
            cpuUsage: getCPUUsage(),
            memory: getMemoryUsed()!,
            vram: KByte(device.currentAllocatedSize / 1024),
            commandBufferReports: commandBufferReports
        )
        repository.persist(report)
    }
}
