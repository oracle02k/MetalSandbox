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
    static let shared = {
        let instance = System()
        return instance
    }();
    
    let app: Application
    let rendererDebugger: RendererDebugger
    let renderer: Renderer
    let debugVM: DebugVM
    
    private init(){
        debugVM = DebugVM()
        rendererDebugger = RendererDebuggerBindVM(debugVM)
        renderer = try! Renderer(rendererDebugger)
        app = Application(renderer)
    }
}
