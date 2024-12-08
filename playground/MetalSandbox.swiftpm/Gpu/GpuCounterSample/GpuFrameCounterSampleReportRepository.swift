struct GpuFrameCounterSampleReport {
    let frame: UInt64
    let contents: GpuCounterSampleReport
}

class GpuFrameCounterSampleReportRepository {
    var reports = [GpuFrameCounterSampleReport]()

    func fetch(groupLabel: String) -> [GpuFrameCounterSampleReport] {
        return reports.filter { report in report.contents.label == groupLabel }
    }

    func fetchAll() -> [GpuFrameCounterSampleReport] {
        return reports
    }

    func persist(_ item: GpuFrameCounterSampleReport) {
        reports.append(item)
    }

    func persist(_ items: [GpuFrameCounterSampleReport]) {
        reports.append(contentsOf: items)
    }

    func deleteAll() {
        reports.removeAll()
    }
}
