import Metal

protocol GpuFunctionTableProvider: RawRepresentable & Hashable & CaseIterable where RawValue == String {
    static var FileName: String { get }
}

protocol GpuFunctionContainerProvider {
    associatedtype FunctionTable: GpuFunctionTableProvider
}

class GpuFunctionContainer<T: GpuFunctionTableProvider>: GpuFunctionContainerProvider {
    typealias FunctionTable = T
    private let gpu: GpuContext
    private var container = [FunctionTable: MTLFunction]()
    private lazy var library: MTLLibrary = uninitialized()
    
    init(gpu: GpuContext) {
        self.gpu = gpu
    }
    
    func build() {
        guard let shaderSource = concatenateTextFilesFromResources() else {
            appFatalError("faild to make shader source.")
        }
        
        do {
            library = try gpu.device.makeLibrary(source: shaderSource, options: nil)
        } catch {
            appFatalError("faild to make library.", error: error)
        }
        
        T.allCases.forEach {
            guard let function = library.makeFunction(name: $0.rawValue) else {
                appFatalError("failed to make function: \($0)")
            }
            container[$0] = function
        }
        
        Logger.log(library.description)
    }
    
    func find(by name: FunctionTable) -> MTLFunction {
        guard let function = container[name] else {
            appFatalError("failed to find function: \(name)")
        }
        return function
    }
    
    private func concatenateTextFilesFromResources() -> String? {
        let fileManager = FileManager.default
        
        // Playgrounds の Resources/Shaders フォルダのパスを取得
        guard let resourcePath = Bundle.main.resourcePath else {
            print("Resources フォルダが見つかりません")
            return nil
        }
        
        do {
            // Shaders フォルダ内のファイル一覧を取得
            let fileURLs = try fileManager.contentsOfDirectory(atPath: resourcePath)
            
            // .txt ファイルのみフィルタリング
            let txtFiles = fileURLs.filter { $0.hasSuffix(".metal.txt") }
            
            // 各ファイルの内容を読み込み結合
            let concatenatedString = try txtFiles.map {
                let filePath = resourcePath + "/" + $0
                return try String(contentsOfFile: filePath, encoding: .utf8)
            }.joined(separator: "\n") // 改行で結合
            
            return concatenatedString
        } catch {
            print("Error reading shader files: \(error)")
            return nil
        }
    }
    
}
