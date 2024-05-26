import SwiftUI

class GpuFunctionContainer {
    enum Name: String, CaseIterable {
        case BasicVertexFunction = "basic_vertex_function"
        case BasicFragmentFunction = "basic_fragment_function"
        case TexcoordVertexFuction = "texcoord_vertex_function"
        case TexcoordFragmentFunction = "texcoord_fragment_function"
    }
    
    private let device: MTLDevice
    private var container: [Name:MTLFunction]
    private lazy var library: MTLLibrary = uninitialized()
        
    init(device: MTLDevice) {
        self.device = device
        container = [:]
    }
    
    func build() {
        do {
            library = try self.device.makeLibrary(source: gpuFunctionSource, options: nil)
            Logger.log("library description: \(library.description)") 
        } catch {
            appFatalError(error.localizedDescription)
        }
        
        Name.allCases.forEach {
            guard let function = library.makeFunction(name: $0.rawValue) else {
                appFatalError("failed to make function: \($0)")
            }            
            container[$0] = function
        }
    }
    
    func find(by name: Name) -> MTLFunction {
        guard let function = container[name] else {
            appFatalError("failed to find function: \(name)")
        }
        return function
    }
}
