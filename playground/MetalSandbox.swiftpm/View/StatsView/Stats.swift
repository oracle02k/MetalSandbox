import Foundation

class CounterSampleReportGroup: Identifiable {
    let id = UUID()
    let name: String
    let reports: [CounterSampleReport]
    
    init(name:String, reports:[CounterSampleReport]){
        self.name = name
        self.reports = reports
    }
}

class Stats {
    let fps: Float
    let dt: MilliSecond
    let cpuUsage: Float
    let memoryUsed: KByte
    let counterSampleReportGroups: [CounterSampleReportGroup]
    
    init(){
        self.fps = .init()
        self.dt = .zero
        self.cpuUsage = .zero
        self.memoryUsed = .zero
        self.counterSampleReportGroups = .init()
    }
    
    init(
        fps: Float,
        dt:MilliSecond,
        cpuUsage: Float,
        memoryUsed:KByte,
        counterSampleReportGroups: [CounterSampleReportGroup]
    ){
        self.fps = fps
        self.dt = dt
        self.cpuUsage = cpuUsage
        self.memoryUsed = memoryUsed
        self.counterSampleReportGroups = counterSampleReportGroups
    }
}
