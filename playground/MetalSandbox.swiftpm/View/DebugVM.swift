import SwiftUI

final class DebugVM: ObservableObject {
    @Published var initLog: String = "initLog"
    @Published var frameLog: String = "frameLog"
}

final class AppDebuggerBindVM: AppDebugger {
    var debugVm: DebugVM
    var initLogText: String {debugVm.initLog }
    var frameLogText: String {debugVm.frameLog }
    private var initLogBuffer = ""
    private var frameLogBuffer = ""

    init(_ debugVm: DebugVM) {
        self.debugVm = debugVm
    }

    func allClear() {
        initLogBuffer = ""
        frameLogBuffer = ""
    }

    func frameClear() {
        frameLogBuffer = ""
    }

    func initLog(_ message: String) {
        initLogBuffer += message + "\n"
    }

    func frameLog(_ message: String) {
        frameLogBuffer += message + "\n"
    }
    
    func flush() {
        debugVm.initLog = initLogBuffer
        debugVm.frameLog = frameLogBuffer
    }
}
