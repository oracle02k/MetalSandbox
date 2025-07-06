import SwiftUI

class GpuCounterSampleReportRepository {
    var reports = [GpuCounterSampleReport]()
    private let lock = NSLock()

    func fetchAll() -> [GpuCounterSampleReport] {
        lock.lock()
        defer { lock.unlock() }
        
        return reports
    }

    func persist(_ item: GpuCounterSampleReport) {
        lock.lock()
        defer { lock.unlock() }
        
        reports.append(item)
    }

    func persist(_ items: [GpuCounterSampleReport]) {
        lock.lock()
        defer { lock.unlock() }
        
        reports.append(contentsOf: items)
    }

    func deleteAll() {
        lock.lock()
        defer { lock.unlock() }
        
        reports.removeAll()
    }

    func count() -> Int {
        lock.lock()
        defer { lock.unlock() }
        
        return reports.count
    }

    func fetchByGroupedType(byFilterId: Int) -> [GpuCounterSampleReportType: [GpuCounterSampleReport]] {
        lock.lock()
        defer { lock.unlock() }
        
        let filtered = reports.filter {$0.counterSampleId == byFilterId}
        return Dictionary(grouping: filtered, by: {$0.type})
    }
}
