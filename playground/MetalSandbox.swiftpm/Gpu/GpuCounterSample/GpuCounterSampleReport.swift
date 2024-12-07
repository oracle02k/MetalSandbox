protocol GpuCounterSampleReport {
    var label:String { get }
    func toString() -> String
}

class MissCounterSampleReport: GpuCounterSampleReport {
    let label:String
    
    init(label:String){
        self.label = label
    }
    
    func toString() -> String {
        return String(format: "%@ miss", label)
    }
}

struct RenderIntervalReport : GpuCounterSampleReport{
    let label: String
    let vertexTime: MilliSecond
    let fragmentTime: MilliSecond
    
    init(label:String, vertexTime:MilliSecond, fragmentTime: MilliSecond){
        self.label = label
        self.vertexTime = vertexTime
        self.fragmentTime = fragmentTime
    }
    
    func toString() -> String {
        return String(format: "%@ vt:%.3fms ft:%.3fms", label, vertexTime, fragmentTime)
    }
}

struct ComputeIntervalReport : GpuCounterSampleReport{
    let label: String
    let time: MilliSecond
    
    init(label:String, time:MilliSecond){
        self.label = label
        self.time = time
    }
    
    func toString() -> String {
        return String(format: "%@ ct:%.3fms", label, time)
    }
}
