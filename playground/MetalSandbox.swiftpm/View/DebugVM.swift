import SwiftUI

final class DebugVM: ObservableObject {
    @Published var gpuTime: CFTimeInterval = 0
    @Published var viewWidth: Int = 0
    @Published var viewHeight: Int = 0
}

final class RendererDebuggerBindVM: RendererDebugger
{
    var debugVm: DebugVM
    
    var gpuTime: CFTimeInterval {
        get { return self.debugVm.gpuTime }
        set { self.debugVm.gpuTime = newValue }
    }
    
    var viewWidth: Int {
        get { return self.debugVm.viewWidth }
        set { self.debugVm.viewWidth = newValue }
    }
    var viewHeight: Int{
        get { return self.debugVm.viewHeight }
        set { self.debugVm.viewHeight = newValue }
    }
    
    init(_ debugVm: DebugVM)
    {
        self.debugVm = debugVm
    }
}
