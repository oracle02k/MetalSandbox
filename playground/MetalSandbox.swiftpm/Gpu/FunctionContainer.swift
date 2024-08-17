import MetalKit

class FunctionContainer<T: RawRepresentable & Hashable & CaseIterable> where T.RawValue == String {
    private let gpu: GpuContext
    private var container = [T: MTLFunction]()
    private lazy var library: MTLLibrary = uninitialized()

    init(with gpu: GpuContext) {
        self.gpu = gpu
    }

    func build(fileName: String) {
        let splited = fileName.split(separator: ".").map {String($0)}
        guard let path = Bundle.main.url(forResource: splited[0], withExtension: splited[1]) else {
            appFatalError("faild to open shader.cpp")
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

    func find(by name: T) -> MTLFunction {
        guard let function = container[name] else {
            appFatalError("failed to find function: \(name)")
        }
        return function
    }

}
