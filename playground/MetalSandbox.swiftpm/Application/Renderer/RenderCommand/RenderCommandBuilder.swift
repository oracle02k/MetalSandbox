import Metal

class FixedArray<T> {
    private var storage: [T]

    init(_ values: [T]) {
        self.storage = values
    }

    init(repeating value: T, count: Int) {
        self.storage = Array(repeating: value, count: count)
    }

    var count: Int { storage.count }

    subscript(index: Int) -> T {
        get {
            guard 0 <= index && index < storage.count else {
                appFatalError("Index out of range")
            }
            return storage[index]
        }
        set {
            guard 0 <= index && index < storage.count else {
                appFatalError("Index out of range")
            }
            return storage[index] = newValue
        }
    }
}

class AttachmentPixelFormts {
    let colors: FixedArray<MTLPixelFormat> = .init(repeating: .invalid, count: 8)
    var depth: MTLPixelFormat = .invalid
    var stencil: MTLPixelFormat = .invalid
}

class RenderDescriptors {
    let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
    var depthStencilDescriptor = MTLDepthStencilDescriptor()
    let tilePipelineDescriptor = MTLTileRenderPipelineDescriptor()
}

class RenderCommandBuilder {
    private let pixelFormats: AttachmentPixelFormts
    private let frameAllocator: GpuFrameAllocator
    private let renderCommandRepository: RenderCommandRepository
    private let functions: ShaderFunctions
    private let renderStateResolver: RenderStateResolver
    private let tileShaderParams: TileShaderParams
    private var renderPipelineDescriptor = MTLRenderPipelineDescriptor()
    private var depthStencilDescriptor = MTLDepthStencilDescriptor()
    private var tilePipelineDescriptor = MTLTileRenderPipelineDescriptor()

    let descriptors = PropertyStack<RenderDescriptors>()

    init(
        pixelFormats: AttachmentPixelFormts,
        frameAllocator: GpuFrameAllocator,
        renderCommandRepository: RenderCommandRepository,
        functions: ShaderFunctions,
        renderStateResolver: RenderStateResolver,
        tileShaderParams: TileShaderParams
    ) {
        self.pixelFormats = pixelFormats
        self.frameAllocator = frameAllocator
        self.renderCommandRepository = renderCommandRepository
        self.functions = functions
        self.renderStateResolver = renderStateResolver
        self.tileShaderParams = tileShaderParams
        descriptors.push(RenderDescriptors())
    }

    func withStateScope(_ body: (RenderCommandBuilder) -> Void) {
        descriptors.push(RenderDescriptors())
        body(self)
        descriptors.pop()
    }

    func setVertexBuffer<T>(_ value: T, index: Int) {
        let allocation = frameAllocator.allocate(size: MemoryLayout<T>.stride)!
        allocation.write(value: value)

        renderCommandRepository.append(SetVertexBuffer(
            buffer: allocation.buffer,
            offset: allocation.offset,
            index: index
        ))
    }

    func setVertexBuffer<T, U: RawRepresentable>(_ value: T, index: U) where U.RawValue == Int {
        setVertexBuffer(value, index: index.rawValue)
    }

    func setVertexBuffer<T>(_ value: [T], index: Int) {
        let allocation = frameAllocator.allocate(size: value.byteLength)!
        allocation.write(from: value)

        renderCommandRepository.append(SetVertexBuffer(
            buffer: allocation.buffer,
            offset: allocation.offset,
            index: index
        ))
    }

    func setVertexBuffer<T, U: RawRepresentable>(_ value: [T], index: U) where U.RawValue == Int {
        setVertexBuffer(value, index: index.rawValue)
    }

    func setFragmentBuffer<T>(_ value: T, index: Int) {
        let allocation = frameAllocator.allocate(size: MemoryLayout<T>.stride)!
        allocation.write(value: value)

        renderCommandRepository.append(SetFragmentBuffer(
            buffer: allocation.buffer,
            offset: allocation.offset,
            index: index
        ))
    }

    func setFragmentBuffer<T, U: RawRepresentable>(_ value: T, index: U) where U.RawValue == Int {
        setFragmentBuffer(value, index: index.rawValue)
    }

    func setFragmentBuffer<T>(_ value: [T], index: Int) {
        let allocation = frameAllocator.allocate(size: value.byteLength)!
        allocation.write(from: value)

        renderCommandRepository.append(SetFragmentBuffer(
            buffer: allocation.buffer,
            offset: allocation.offset,
            index: index
        ))
    }

    func setFragmentBuffer<T, U: RawRepresentable>(_ value: [T], index: U) where U.RawValue == Int {
        setFragmentBuffer(value, index: index.rawValue)
    }

    func bindVertexBuffer<U: RawRepresentable>(buffer: MTLBuffer, index: U) where U.RawValue == Int {
        renderCommandRepository.append(SetVertexBuffer(
            buffer: buffer,
            offset: 0,
            index: index.rawValue
        ))
    }

    func drawPrimitives(type: MTLPrimitiveType, vertexStart: Int, vertexCount: Int) {
        let current = descriptors.current
        for i in 0..<pixelFormats.colors.count {
            current.renderPipelineDescriptor.colorAttachments[i].pixelFormat = pixelFormats.colors[i]
        }
        current.renderPipelineDescriptor.depthAttachmentPixelFormat = pixelFormats.depth
        current.renderPipelineDescriptor.stencilAttachmentPixelFormat = pixelFormats.stencil

        let pso = renderStateResolver.resolvePipelineState(descriptors.current.renderPipelineDescriptor)
        renderCommandRepository.append(
            SetRenderPipelineState(renderPipelineState: pso)
        )

        let state = renderStateResolver.resolveDepthStencilState(descriptors.current.depthStencilDescriptor)
        renderCommandRepository.append(
            SetDepthStencilState(depthStencilState: state)
        )

        renderCommandRepository.append(
            DrawPrimitives(type: type, vertexStart: vertexStart, vertexCount: vertexCount)
        )
    }

    func dispatchThreadsPerTile() {
        let current = descriptors.current
        for i in 0..<pixelFormats.colors.count {
            current.tilePipelineDescriptor.colorAttachments[i].pixelFormat = pixelFormats.colors[i]
        }

        let pso = renderStateResolver.resolveTilePipelineState(descriptors.current.tilePipelineDescriptor)
        renderCommandRepository.append(
            SetRenderPipelineState(renderPipelineState: pso)
        )

        let state = renderStateResolver.resolveDepthStencilState(descriptors.current.depthStencilDescriptor)
        renderCommandRepository.append(
            SetDepthStencilState(depthStencilState: state)
        )

        renderCommandRepository.append(
            DispatchThreadsPerTile(threadsPerTile: tileShaderParams.tileSize)
        )

        tileShaderParams.setMaxImageBlockSampleLength(tryValue: pso.imageblockSampleLength)
    }

    func setFragmentTexture(_ texture: MTLTexture, index: Int) {
        renderCommandRepository.append(
            SetFragmentTexture(texture: texture, index: index)
        )
    }

    func withRenderPipelineState(_ body: (MTLRenderPipelineDescriptor) -> Void) {
        descriptors.current.renderPipelineDescriptor.reset()
        body(descriptors.current.renderPipelineDescriptor)
    }

    func withDepthStencilState(_ body: (MTLDepthStencilDescriptor) -> Void) {
        descriptors.current.depthStencilDescriptor = MTLDepthStencilDescriptor()
        body(descriptors.current.depthStencilDescriptor)
    }

    func withTileRenderState(_ body: (MTLTileRenderPipelineDescriptor) -> Void) {
        descriptors.current.tilePipelineDescriptor.reset()
        body(descriptors.current.tilePipelineDescriptor)
    }

    func findFunction(by name: ShaderFunctions.FunctionTable) -> MTLFunction {
        return functions.find(by: name)
    }

    func withDebugGroup(_ label: String, _ body: () -> Void) {
        renderCommandRepository.append(PushDebugGroup(label: label))
        body()
        renderCommandRepository.append(PopDebugGroup())
    }

    func setCullMode(_ mode: MTLCullMode) {
        renderCommandRepository.append(SetCullMode(mode: mode))
    }
}
