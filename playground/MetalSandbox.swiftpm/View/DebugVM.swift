import SwiftUI

final class DebugVM: ObservableObject {
    @Published var gpuAllocatedByteSize = 0
    @Published var gpuTime: CFTimeInterval = 0
    @Published var viewWidth: Int = 0
    @Published var viewHeight: Int = 0
    @Published var log: String = "test consle"
}

final class GpuDebuggerBindVM: GpuDebugger {
    var debugVm: DebugVM

    var gpuAllocatedByteSize: Int {
        get { return self.debugVm.gpuAllocatedByteSize }
        set { self.debugVm.gpuAllocatedByteSize = newValue }
    }
    var gpuTime: CFTimeInterval {
        get { return self.debugVm.gpuTime }
        set { self.debugVm.gpuTime = newValue }
    }

    var viewWidth: Int {
        get { return self.debugVm.viewWidth }
        set { self.debugVm.viewWidth = newValue }
    }
    var viewHeight: Int {
        get { return self.debugVm.viewHeight }
        set { self.debugVm.viewHeight = newValue }
    }

    var log: String {
        get { return self.debugVm.log }
    }

    init(_ debugVm: DebugVM) {
        self.debugVm = debugVm
    }

    func framInit() {
        debugVm.log = ""
    }

    func addLog(_ message: String) {
        debugVm.log += message + "\n"
    }
}
