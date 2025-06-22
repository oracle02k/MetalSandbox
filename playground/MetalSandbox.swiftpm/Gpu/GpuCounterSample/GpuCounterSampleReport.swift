import Foundation

enum GpuCounterSampleReportType: Comparable {
    case VertexTime
    case FragmentTime
    case ComputeTime
}

class GpuCounterSampleReport: Identifiable {
    var id: Int {counterSampleId}
    let counterSampleId: Int
    let frame: UInt64
    let type: GpuCounterSampleReportType
    let interval: MilliSecond
    
    init(counterSampleId: Int, frame: UInt64, type: GpuCounterSampleReportType, interval: MilliSecond) {
        self.counterSampleId = counterSampleId
        self.frame = frame
        self.type = type
        self.interval = interval
    }
}
