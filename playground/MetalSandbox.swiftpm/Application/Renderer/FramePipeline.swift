import MetalKit

protocol FramePipeline {
    func changeSize(viewportSize: CGSize)
    func update(drawTo metalLayer: CAMetalLayer, 
                logTo frameLogger: FrameStatisticsLogger?, 
                _ frameComplited: @escaping ()->Void)
}

struct CommandBufferLog {
    let label: String
    let commandBuffer: MTLCommandBuffer
    let details:[String]
}

class FrameStatisticsLogger {
    var commandBufferLogs = [CommandBufferLog]()
    var frameStatus: FrameStatus!
    var cpuUsage: Float!
    var memory: KByte!
    var vram: Int!
    
    func addCommandBufferLog(_ log:CommandBufferLog){
        commandBufferLogs.append(log)
    }
    
    func setFrameStatus(_ frameStatus: FrameStatus){
        self.frameStatus = frameStatus
    }
    
    func measureCpuAndMemory() {
        cpuUsage = getCPUUsage()
        memory = getMemoryUsed()
    }
    
    func measureMetal(_ device: MTLDevice) {
        vram = device.currentAllocatedSize / 1024
    }
    
    func debugLog(){
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.groupingSize = 3
        
        Debug.frameLog(String(
            format: "FPS pref:%.3f act:%.3f dt:%.3fms disp:%.3fms",
            frameStatus.preferredFps,
            frameStatus.actualFps,
            frameStatus.delta.milliSecond,
            frameStatus.displayLinkDuration
        ))
        
        Debug.frameLog(String(format: "CPU usage:%.3f%%", cpuUsage))
        
        if let v = f.string(from: NSNumber(value: memory)) {
            Debug.frameLog(String(format: "MEM used:%@KByte", v)) 
        }
        
        if let v = f.string(from: NSNumber(value: vram)) {
            Debug.frameLog(String(format: "VRAM used:%@KByte", v)) 
        }
        
        for log in commandBufferLogs {
            let time = log.commandBuffer.debugGpuTime()
            Debug.frameLog(String(format: "CMDBUFFER %@:%.3fms", log.label, time))
            for detail in log.details {
                Debug.frameLog("- \(detail)")
            }
        }        
    }
}

