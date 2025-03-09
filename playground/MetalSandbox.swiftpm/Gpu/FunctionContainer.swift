import MetalKit

protocol FunctionTableProvider:RawRepresentable & Hashable & CaseIterable where RawValue == String {
    static var FileName:String { get }
}

protocol FunctionContainerProvider {
    associatedtype FunctionTable: FunctionTableProvider
}

class FunctionContainer<T: FunctionTableProvider> : FunctionContainerProvider {
    typealias FunctionTable = T
    private let gpu: GpuContext
    private var container = [FunctionTable: MTLFunction]()
    private lazy var library: MTLLibrary = uninitialized()

    init(with gpu: GpuContext) {
        self.gpu = gpu
    }

    func build() {
        let splited = FunctionTable.FileName.split(separator: ".").map {String($0)}
        guard let path = Bundle.main.url(forResource: splited[0], withExtension: splited[1]) else {
            appFatalError("faild to open shader.txt")
        }

        do {
            let shaderFile = try String(contentsOf: path, encoding: .utf8)
            library = try gpu.device.makeLibrary(source: shaderFile, options: nil)
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

}
