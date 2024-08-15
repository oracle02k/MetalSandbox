import MetalKit

class System {
    static let shared = { System() }()

    let appDebuger: AppDebugger
    let debugVM: DebugVM
    lazy var app: Application = uninitialized()

    private init() {
        self.debugVM = DebugVM()
        self.appDebuger = AppDebuggerBindVM(debugVM)
    }

    func build() {
        Logger.log("begin entrypoint init")
        self.app = Application(
            gpu: DIContainer.resolve(GpuContext.self),
            frameBuffer: FrameBuffer()
        )

        app.build()
        Logger.log("done entrypoint init")
    }
}
