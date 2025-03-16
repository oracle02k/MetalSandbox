import SwiftUI

class CounterSampleReportRepository {
    var reports = [CounterSampleReport]()

    func fetchAll() -> [CounterSampleReport] {
        return reports
    }

    func persist(_ item: CounterSampleReport) {
        reports.append(item)
    }

    func persist(_ items: [CounterSampleReport]) {
        reports.append(contentsOf: items)
    }

    func deleteAll() {
        reports.removeAll()
    }

    func count() -> Int {
        return reports.count
    }

    func fetchByGroupedType(byFilterId: Int) -> [CounterSampleReportType: [CounterSampleReport]] {
        let filtered = reports.filter {$0.counterSampleId == byFilterId}
        return Dictionary(grouping: filtered, by: {$0.type})
    }
}
