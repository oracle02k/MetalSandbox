import Foundation

enum CounterSampleReportType: Comparable {
    case VertexTime
    case FragmentTime
    case ComputeTime
}

class CounterSampleReport: Identifiable {
    var id: Int {counterSampleId}
    let counterSampleId: Int
    let frame: UInt64
    let type: CounterSampleReportType
    let interval: MilliSecond

    init(counterSampleId: Int, frame: UInt64, type: CounterSampleReportType, interval: MilliSecond) {
        self.counterSampleId = counterSampleId
        self.frame = frame
        self.type = type
        self.interval = interval
    }
}
