import SwiftUI

final class DebugVM: ObservableObject {
    @Published var initLog: String = "initLog"
    @Published var frameLog: String = "frameLog"
}

final class AppDebuggerBindVM: AppDebugger {
    var debugVm: DebugVM
    var initLogText: String {debugVm.initLog }
    var frameLogText: String {debugVm.frameLog }

    init(_ debugVm: DebugVM) {
        self.debugVm = debugVm
    }

    func allClear() {
        debugVm.initLog = ""
        debugVm.frameLog = ""
    }

    func frameClear() {
        debugVm.frameLog = ""
    }

    func initLog(_ message: String) {
        debugVm.initLog += message + "\n"
    }

    func frameLog(_ message: String) {
        debugVm.frameLog += message + "\n"
    }
}
