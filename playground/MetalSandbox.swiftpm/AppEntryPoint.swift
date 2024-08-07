import SwiftUI
import PlaygroundTester

// @main
struct AppTest: App {
    init() {
        PlaygroundTesterConfiguration.isTesting = true
    }
    var body: some Scene {
        WindowGroup {
            PlaygroundTester.PlaygroundTesterWrapperView {
                // YourContentView()
            }
        }
    }
}

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
