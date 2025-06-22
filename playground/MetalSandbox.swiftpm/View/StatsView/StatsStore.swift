import Observation

@Observable
class StatsStore {
    private(set) var stats = Stats()

    @ObservationIgnored
    private let frameStatsRepository: FrameStatsReportRepository

    @ObservationIgnored
    private let counterSampleSummaryRepository: GpuCounterSampleSummaryRepository

    @ObservationIgnored
    private let counterSampleReportRepository: GpuCounterSampleReportRepository

    init(
        frameStatsRepository: FrameStatsReportRepository,
        counterSampleSummaryRepository: GpuCounterSampleSummaryRepository,
        counterSampleReportRepository: GpuCounterSampleReportRepository
    ) {
        self.frameStatsRepository = frameStatsRepository
        self.counterSampleSummaryRepository = counterSampleSummaryRepository
        self.counterSampleReportRepository = counterSampleReportRepository
    }

    func refresh() {
        let reports = frameStatsRepository.fetchAll()
        if reports.count == 0 { return }

        let fps = reports.map { $0.frameStatus.actualFps }.average()
        let dt = reports.map { $0.frameStatus.delta.microSecond }.average()
        let cpu = reports.map { $0.cpuUsage }.average() * 100.0
        let memory = reports.map { $0.memory }.max()!
        let gpu = reports.map { $0.gpuTime }.average()
        let vram = reports.map {$0.vram}.max()!

        let groups = counterSampleSummaryRepository.fetchAll().map { summary in
            let reports = counterSampleReportRepository
                .fetchByGroupedType(byFilterId: summary.id)
                .map { (type, values) in
                    GpuCounterSampleReport(
                        counterSampleId: summary.id,
                        frame: 0,
                        type: type,
                        interval: values.map { $0.interval }.average()
                    )
                }
                .sorted { $0.type < $1.type }  // `sorted()` をここで適用
            return CounterSampleReportGroup(name: summary.name, reports: reports)
        }

        stats = Stats(
            fps: fps,
            dt: dt,
            cpuUsage: cpu,
            memoryUsed: memory,
            gpuTime: gpu,
            vram: vram,
            counterSampleReportGroups: groups
        )

        frameStatsRepository.deleteAll()
        counterSampleReportRepository.deleteAll()
    }
}
