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
        _ = System.shared;
        return true
    }
}

class System{
    static let shared = { () -> System in 
        let instance = System()
        return instance
    }();
    
    let app: Application
    let gpuDebugger: GpuDebugger
    let gpuContext: GpuContext
    let gpuFunctionContainer: GpuFunctionContainer
    let renderPipelineStateContainer: RenderPipelineStateContainer
    let debugVM: DebugVM
    let device: MTLDevice
    
    private init(){
        Logger.log("begin entrypoint init")
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            appFatalError("GPU not available ")
        }
        self.device = device
        
        debugVM = DebugVM()
        gpuDebugger = GpuDebuggerBindVM(debugVM)
        
        gpuFunctionContainer = GpuFunctionContainer(device: device)
        gpuFunctionContainer.build()
        
        renderPipelineStateContainer = RenderPipelineStateContainer(device: device)
        
        gpuContext = GpuContext(
            device: device,
            gpuFunctionContainer: gpuFunctionContainer,
            renderPipelineStateContainer: renderPipelineStateContainer,
            gpuDebugger: gpuDebugger
        )
        gpuContext.build()
        
        app = Application(gpuContext)
        app.build()
        
        Logger.log("done entrypoint init")
    }
}
