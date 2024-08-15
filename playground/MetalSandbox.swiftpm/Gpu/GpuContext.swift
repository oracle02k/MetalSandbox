import MetalKit
import Foundation

class GpuContext {
    enum Function: String, CaseIterable {
        case Simple2dVertexFunction = "simple2d_vertex_function"
        case Simple2dFragmentFunction = "simple2d_fragment_function"
        case RedFragmentFunction = "red_fragment_function"
        case TexcoordVertexFuction = "texcoord_vertex_function"
        case TexcoordFragmentFunction = "texcoord_fragment_function"
        case RasterOrderGroup0Fragment = "raster_order_group0_fragment"
        case RasterOrderGroup1Fragment = "raster_order_group1_fragment"
        case AddArrayComputeFunction = "add_arrays_compute_function"
        case IndirectRendererVertexFunction = "IndirectRenderer::vertexShader"
        case IndirectRendererVertexFunction2 = "IndirectRenderer::vertexShader2"
        case IndirectRendererFragmentFunction = "IndirectRenderer::fragmentShader"
        case TileRendererFowardVertext = "TileRenderer::forwardVertex"
        case TileRendererOpaqueFragment = "TileRenderer::processOpaqueFragment"
        case TileRendererTransparentFragment = "TileRenderer::processTransparentFragment"
        case TileRendererBlendFragments = "TileRenderer::blendFragments"
        case TileRendererInitTransparentFragmentStore = "TileRenderer::initTransparentFragmentStore"
        case TileRendererQuadPassVertex = "TileRenderer::quadPassVertex"
    }

    lazy var device: MTLDevice = uninitialized()
    private let metalDeviceResolver: MetalDeviceResolver
    private var container = [Function: MTLFunction]()
    private lazy var library: MTLLibrary = uninitialized()
    private lazy var commandQueue: MTLCommandQueue = uninitialized()

    init(resolver: MetalDeviceResolver) {
        self.metalDeviceResolver = resolver
    }

    func build() {
        device = metalDeviceResolver.resolve()
        commandQueue = buildCommandQueue()
        library = buildFunction()
    }

    private func buildCommandQueue() -> MTLCommandQueue {
        guard let commandQueue = device.makeCommandQueue() else {
            appFatalError("failed to make command queue.")
        }
        return commandQueue
    }

    private func buildFunction() -> MTLLibrary {
        guard let path = Bundle.main.url(forResource: "shader", withExtension: "cpp") else {
            appFatalError("faild to open shader.cpp")
        }

        var library: MTLLibrary
        do {
            let shaderFile = try String(contentsOf: path, encoding: .utf8)
            library = try self.device.makeLibrary(source: shaderFile, options: nil)
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

        return library
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

    func doCommand<Result>(_ body: (_ commandBuffer: MTLCommandBuffer) throws -> Result) rethrows -> Result {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            appFatalError("failed to make command buffer.")
        }
        return try body(commandBuffer)
    }

    func makeCommandBuffer() -> MTLCommandBuffer {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            appFatalError("failed to make command buffer.")
        }
        return commandBuffer
    }

    func makeTypedBuffer<T>(elementCount: Int = 1, align: Int? = nil, options: MTLResourceOptions) -> TypedBuffer<T> {
        let alignedBuffer = AlignedBuffer<T>(count: elementCount, align: align)
        let typedBuffer = TypedBuffer<T>(alignedBuffer)
        let rawBuffer = makeBuffer(length: typedBuffer.byteSize, options: options)
        typedBuffer.bind(rawBuffer)
        return typedBuffer
    }

    func makeBuffer<T>(data: [T], options: MTLResourceOptions) -> MTLBuffer {
        return data.withUnsafeBytes {
            guard let buffer = device.makeBuffer(bytes: $0.baseAddress!, length: data.byteLength, options: options) else {
                appFatalError("failed to make buffer.")
            }
            return buffer
        }
    }

    func makeBuffer(length: Int, options: MTLResourceOptions) -> MTLBuffer {
        guard let buffer = device.makeBuffer(length: length, options: options) else {
            appFatalError("failed to make buffer.")
        }
        return buffer
    }

    func makeTexture(_ descriptor: MTLTextureDescriptor) -> MTLTexture {
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            appFatalError("failed to make texture.")
        }
        return texture
    }
}
