import Observation

@Observable
class StatsStore {
    private(set) var stats = Stats()
    @ObservationIgnored private let repository: FrameStatsReportRepository
    
    init(repository: FrameStatsReportRepository){
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
        
        stats = Stats(fps:fps, dt:dt, cpuUsage:cpu, memoryUsed:memory)
        
        repository.deleteAll()
    }
}
