class Debug {
    static let appDebuger = {
        DIContainer.resolve(AppDebuggerBindVM.self)
    }()

    static func allClear() {
        appDebuger.allClear()
    }

    static func frameClear() {
        appDebuger.frameClear()
    }

    static func initLog(_ message: String) {
        appDebuger.initLog(message)
    }

    static func frameLog(_ message: String) {
        appDebuger.frameLog(message)
    }

    static func flush() {
        appDebuger.flush()
    }
}
