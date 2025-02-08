class Stats {
    let fps: Float
    let dt: MilliSecond
    let cpuUsage: Float
    let memoryUsed: KByte
    
    init(){
        self.fps = .init()
        self.dt = .zero
        self.cpuUsage = .zero
        self.memoryUsed = .zero
    }
    
    init(fps: Float, dt:MilliSecond, cpuUsage: Float, memoryUsed:KByte){
        self.fps = fps
        self.dt = dt
        self.cpuUsage = cpuUsage
        self.memoryUsed = memoryUsed
    }
}
