import Observation

@Observable
class FrameStatsReportRepository {
    var reports = [FrameStatsReport]()
    
    func fetch(frameId: UInt64) -> [FrameStatsReport] {
        return reports.filter { report in report.frameId == frameId }
    }
    
    func fetchAll() -> [FrameStatsReport] {
        return reports
    }
    
    func persist(_ report: FrameStatsReport){
        reports.append(report)    
    }
    
    func persist(_ reports: [FrameStatsReport]){
        self.reports.append(contentsOf: reports)
    }
    
    func deleteAll(){
        reports.removeAll()
    }
}

