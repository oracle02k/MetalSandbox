class Debug {
    static func allClear() {
        System.shared.appDebuger.allClear()
    }
    
    static func frameClear() {
        System.shared.appDebuger.frameClear()
    }
    
    static func initLog(_ message: String) {
        System.shared.appDebuger.frameLog(message)
    }
    
    static func frameLog(_ message: String) {
        System.shared.appDebuger.frameLog(message)
    }
}
