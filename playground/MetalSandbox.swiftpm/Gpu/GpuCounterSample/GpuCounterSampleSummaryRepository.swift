import SwiftUI

class GpuCounterSampleSummaryRepository {
    var summaries = [GpuCounterSampleSummary]()

    func fetchAll() -> [GpuCounterSampleSummary] {
        return summaries
    }

    func first(_ name: String) -> GpuCounterSampleSummary? {
        summaries.first { $0.name == name}
    }

    func persist(_ item: GpuCounterSampleSummary) {
        summaries.append(item)
    }

    func persist(_ items: [GpuCounterSampleSummary]) {
        summaries.append(contentsOf: items)
    }

    func deleteAll() {
        summaries.removeAll()
    }

    func count() -> Int {
        return summaries.count
    }
}
