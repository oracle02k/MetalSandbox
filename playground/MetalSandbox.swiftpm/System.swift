import MetalKit

class System {
    static let shared = { System() }()
    
    let appDebuger: AppDebugger
    let debugVM: DebugVM
    lazy var device: MTLDevice = uninitialized()
    lazy var app: Application = uninitialized()
    
    private init( ) {
        self.debugVM = DebugVM()
        self.appDebuger = AppDebuggerBindVM(debugVM)
    }
    
    func build(_ device: MTLDevice) {
        Logger.log("begin entrypoint init")
        self.device = device
        self.app = Application(
            commandQueue: MetalCommandQueue(device),
            pipelineStateFactory: MetalPipelineStateFactory(device),
            resourceFactory: MetalResourceFactory(device),
            indexedMeshFactory: IndexedMesh.Factory(device),
            meshFactory: Mesh.Factory(device)
        )
        
        app.build()
        Logger.log("done entrypoint init")
    }
}

