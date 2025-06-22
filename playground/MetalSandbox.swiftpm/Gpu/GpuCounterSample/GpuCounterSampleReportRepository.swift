import SwiftUI

class GpuCounterSampleReportRepository {
    var reports = [GpuCounterSampleReport]()
    
    func fetchAll() -> [GpuCounterSampleReport] {
        return reports
    }
    
    func persist(_ item: GpuCounterSampleReport) {
        reports.append(item)
    }
    
    func persist(_ items: [GpuCounterSampleReport]) {
        reports.append(contentsOf: items)
    }
    
    func deleteAll() {
        reports.removeAll()
    }
    
    func count() -> Int {
        return reports.count
    }
    
    func fetchByGroupedType(byFilterId: Int) -> [GpuCounterSampleReportType: [GpuCounterSampleReport]] {
        let filtered = reports.filter {$0.counterSampleId == byFilterId}
        return Dictionary(grouping: filtered, by: {$0.type})
    }
}
