import SwiftUI

@Observable
class StatsModel {
    private(set) var fps: String = "0fps"
    private(set) var dt: String = "0ms"
    private(set) var cpuUsage: String = "0%"
    private(set) var memoryUsed: String = "0KB"

    private let repository: FrameStatsReportRepository

    init(repository: FrameStatsReportRepository) {
        self.repository = repository
    }

    func refresh() {
        let reports = repository.fetchAll()
        guard reports.count > 0 else {
            return
        }

        let fps = reports.map { $0.frameStatus.actualFps }.average()
        let dt = reports.map { $0.frameStatus.delta.microSecond }.average()
        let cpu = reports.map { $0.cpuUsage }.average() * 100.0
        let memory = reports.map { $0.memory }.max()!

        self.fps = String(format: "%.2ffps", fps)
        self.dt = String(format: "%.2fms", dt)
        cpuUsage = String(format: "%.2f%%", cpu)
        memoryUsed = String(format: "%dKB", memory)

        repository.deleteAll()
    }
}
