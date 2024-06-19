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
        _ = System.shared
        return true
    }
}

class System {
    static let shared = {
        let instance = System()
        return instance
    }()

    let app: Application
    let gpuDebugger: GpuDebugger
    let debugVM: DebugVM
    let device: MTLDevice
    
    private init( ) {
        Logger.log("begin entrypoint init")
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            appFatalError("GPU not available ")
        }
        self.device = device
        
        debugVM = DebugVM()
        gpuDebugger = GpuDebuggerBindVM(debugVM)
        
        app = Application(
            commandQueue: MetalCommandQueue(device),
            pipelineStateFactory: MetalPipelineStateFactory(device),
            resourceFactory: MetalResourceFactory(device),
            indexedPrimitivesFactory: IndexedPrimitives.Factory(device)
        )
        app.build()

        Logger.log("done entrypoint init")
    }
}
