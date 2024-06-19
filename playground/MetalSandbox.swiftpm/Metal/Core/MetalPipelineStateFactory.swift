import MetalKit

class MetalPipelineStateFactory {
    enum Function: String, CaseIterable {
        case BasicVertexFunction = "basic_vertex_function"
        case BasicFragmentFunction = "basic_fragment_function"
        case RedFragmentFunction = "red_fragment_function"
        case TexcoordVertexFuction = "texcoord_vertex_function"
        case TexcoordFragmentFunction = "texcoord_fragment_function"
        case AddArrayComputeFunction = "add_arrays_compute_function"
    }

    private let device: MTLDevice
    private var container: [Function: MTLFunction]
    private lazy var library: MTLLibrary = uninitialized()

    init(_ device: MTLDevice) {
        self.device = device
        self.container = [:]
    }

    func build() {
        do {
            library = try self.device.makeLibrary(source: metalFunctionSource, options: nil)
        } catch {
            appFatalError("faild to make library.", error: error)
        }

        Function.allCases.forEach {
            guard let function = library.makeFunction(name: $0.rawValue) else {
                appFatalError("failed to make function: \($0)")
            }
            container[$0] = function
        }
        Logger.log(library.description)
    }

    func findFunction(by name: Function) -> MTLFunction {
        guard let function = container[name] else {
            appFatalError("failed to find function: \(name)")
        }
        return function
    }

    func makeRenderPipelineState(_ descriptor: MTLRenderPipelineDescriptor) -> MTLRenderPipelineState {
        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            appFatalError("failed to make render pipeline state.", error: error)
        }
    }

    func makeDepthStancilState(_ descriptor: MTLDepthStencilDescriptor) -> MTLDepthStencilState {
        guard let depthStencilState = device.makeDepthStencilState(descriptor: descriptor) else {
            appFatalError("failed to make depth stencil state.")
        }
        return depthStencilState
    }

    func makeComputePipelineState(_ descriptor: MTLComputePipelineDescriptor) -> MTLComputePipelineState {
        do {
            return try device.makeComputePipelineState(descriptor: descriptor, options: .init(), reflection: nil)
        } catch {
            appFatalError("failed to make render pipeline state.", error: error)
        }
    }
}
