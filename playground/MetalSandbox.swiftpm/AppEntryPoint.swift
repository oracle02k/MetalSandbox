import SwiftUI

@main
struct AppEntryPoint: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        guard let device = MTLCreateSystemDefaultDevice() else {
            appFatalError("GPU not available ")
        }

        System.shared.build(device)
        return true
    }
}

class System {
    static let shared = { System() }()

    let gpuDebugger: GpuDebugger
    let debugVM: DebugVM
    lazy var device: MTLDevice = uninitialized()
    lazy var app: Application = uninitialized()

    private init( ) {
        self.debugVM = DebugVM()
        self.gpuDebugger = GpuDebuggerBindVM(debugVM)
    }

    func build(_ device: MTLDevice) {
        Logger.log("begin entrypoint init")
        self.device = device
        self.app = Application(
            commandQueue: MetalCommandQueue(device),
            pipelineStateFactory: MetalPipelineStateFactory(device),
            resourceFactory: MetalResourceFactory(device),
            indexedPrimitivesFactory: IndexedPrimitives.Factory(device),
            primitivesFactory: Primitives.Factory(device)
        )

        app.build()
        Logger.log("done entrypoint init")
    }
}
