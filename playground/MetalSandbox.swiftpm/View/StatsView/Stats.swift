import Foundation

class CounterSampleReportGroup: Identifiable {
    let id = UUID()
    let name: String
    let reports: [GpuCounterSampleReport]

    init(name: String, reports: [GpuCounterSampleReport]) {
        self.name = name
        self.reports = reports
    }
}

class Stats {
    let fps: Float
    let dt: MilliSecond
    let cpuUsage: Float
    let memoryUsed: KByte
    let gpuTime: MilliSecond
    let vram: KByte
    let counterSampleReportGroups: [CounterSampleReportGroup]

    init() {
        self.fps = .init()
        self.dt = .zero
        self.cpuUsage = .zero
        self.memoryUsed = .zero
        self.gpuTime = .zero
        self.vram = .zero
        self.counterSampleReportGroups = .init()
    }

    init(
        fps: Float,
        dt: MilliSecond,
        cpuUsage: Float,
        memoryUsed: KByte,
        gpuTime: MilliSecond,
        vram: KByte,
        counterSampleReportGroups: [CounterSampleReportGroup]
    ) {
        self.fps = fps
        self.dt = dt
        self.cpuUsage = cpuUsage
        self.memoryUsed = memoryUsed
        self.gpuTime = gpuTime
        self.vram = vram
        self.counterSampleReportGroups = counterSampleReportGroups
    }
}
