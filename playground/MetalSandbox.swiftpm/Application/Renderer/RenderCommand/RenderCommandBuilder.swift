import Metal

class AttachmentPixelFormats {
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
    private let pixelFormats: AttachmentPixelFormats
    private let frameAllocator: GpuTransientAllocator
    private let renderCommandRepository: RenderCommandRepository
    private let functions: ShaderFunctions
    private let renderStateResolver: RenderStateResolver
    private let tileShaderParams: TileShaderParams
    private var renderPipelineDescriptor = MTLRenderPipelineDescriptor()
    private var depthStencilDescriptor = MTLDepthStencilDescriptor()
    private var tilePipelineDescriptor = MTLTileRenderPipelineDescriptor()
    private let vertexHeapBlocks: FixedArray<GpuTransientHeapBlock?> = .init(repeating: nil, count: 8)
    private let fragmentHeapBlocks: FixedArray<GpuTransientHeapBlock?> = .init(repeating: nil, count: 8)
    private let vertexBufferBindings: FixedArray<GpuBufferBinding?> = .init(repeating: nil, count: 8)
    private let fragmentBufferBindings: FixedArray<GpuBufferBinding?> = .init(repeating: nil, count: 8)
    private var renderPipelineState: MTLRenderPipelineState?
    private var tilePipelineState: MTLRenderPipelineState?
    private var depthStencilState: MTLDepthStencilState?

    let descriptors = PropertyStack<RenderDescriptors>()

    init(
        pixelFormats: AttachmentPixelFormats,
        frameAllocator: GpuTransientAllocator,
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

    func drawPrimitives(type: MTLPrimitiveType, vertexStart: Int, vertexCount: Int) {
        let current = descriptors.current
        for i in 0..<pixelFormats.colors.count {
            current.renderPipelineDescriptor.colorAttachments[i].pixelFormat = pixelFormats.colors[i]
        }
        current.renderPipelineDescriptor.depthAttachmentPixelFormat = pixelFormats.depth
        current.renderPipelineDescriptor.stencilAttachmentPixelFormat = pixelFormats.stencil

        updateRenderPipelineStateIfNeeded()
        updateDepthStencilStateIfNeeded()

        renderCommandRepository.append(
            DrawPrimitives(type: type, vertexStart: vertexStart, vertexCount: vertexCount)
        )
    }

    func dispatchThreadsPerTile() {
        let current = descriptors.current
        for i in 0..<pixelFormats.colors.count {
            current.tilePipelineDescriptor.colorAttachments[i].pixelFormat = pixelFormats.colors[i]
        }

        updateTilePipelineStateIfNeeded()
        updateDepthStencilStateIfNeeded()

        renderCommandRepository.append(
            DispatchThreadsPerTile(threadsPerTile: tileShaderParams.tileSize)
        )
    }

    private func updateRenderPipelineStateIfNeeded() {
        let newState = renderStateResolver.resolvePipelineState(descriptors.current.renderPipelineDescriptor)
        guard newState !== renderPipelineState else {
            return
        }

        renderPipelineState = newState
        renderCommandRepository.append(SetRenderPipelineState(renderPipelineState: newState))
    }

    private func updateTilePipelineStateIfNeeded() {
        let newState = renderStateResolver.resolveTilePipelineState(descriptors.current.tilePipelineDescriptor)
        guard newState !== tilePipelineState else {
            return
        }

        tilePipelineState = newState
        renderCommandRepository.append(SetRenderPipelineState(renderPipelineState: newState))
        tileShaderParams.setMaxImageBlockSampleLength(tryValue: newState.imageblockSampleLength)
    }

    private func updateDepthStencilStateIfNeeded() {
        let newState = renderStateResolver.resolveDepthStencilState(descriptors.current.depthStencilDescriptor)
        guard newState !== depthStencilState else {
            return
        }

        depthStencilState = newState
        renderCommandRepository.append(SetDepthStencilState(depthStencilState: newState))
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

    func allocFrameHeapBlock<T>(_ type: T.Type, length: Int = 1) -> GpuTransientHeapBlock {
        return frameAllocator.allocate(size: MemoryLayout<T>.stride * length)!
    }
}

extension RenderCommandBuilder {
    enum BindType {
        case vertex
        case fragment

        func setBufferCommand(_ buffer: MTLBuffer, offset: Int, index: Int) -> RenderCommand {
            return switch self {
            case .vertex: SetVertexBuffer(buffer: buffer, offset: offset, index: index)
            case .fragment: SetFragmentBuffer(buffer: buffer, offset: offset, index: index)
            }
        }

        func setOffsetCommand(_ offset: Int, index: Int) -> RenderCommand {
            return switch self {
            case .vertex: SetVertexBufferOffset(offset: offset, index: index)
            case .fragment: SetFragmentBufferOffset(offset: offset, index: index)
            }
        }
    }

    private func bindBuffer(type: BindType, newBinding: GpuBufferBinding, index: Int) {
        let bindings = switch type {
        case .vertex: vertexBufferBindings
        case .fragment: fragmentBufferBindings
        }

        guard let currentBinding = bindings[index] else {
            bindings[index] = newBinding
            renderCommandRepository.append(
                type.setBufferCommand(newBinding.buffer, offset: newBinding.offset, index: index)
            )
            return
        }

        if currentBinding == newBinding {
            return
        }

        if currentBinding.buffer === newBinding.buffer {
            bindings[index] = newBinding
            renderCommandRepository.append(type.setOffsetCommand(newBinding.offset, index: index))
            return
        }

        bindings[index] = newBinding
        renderCommandRepository.append(
            type.setBufferCommand(newBinding.buffer, offset: newBinding.offset, index: index)
        )
    }

    func bindVertexBuffer(_ binding: GpuBufferBinding, index: Int) {
        bindBuffer(type: .vertex, newBinding: binding, index: index)
    }

    func bindVertexBuffer(_ bufferRegion: GpuBufferRegion, offset: Int = 0, index: Int) {
        let binding = bufferRegion.binding(at: offset)
        bindBuffer(type: .vertex, newBinding: binding, index: index)
    }

    func bindVertexBuffer<U: RawRepresentable>(_ bufferRegion: GpuBufferRegion, index: U) where U.RawValue == Int {
        bindVertexBuffer(bufferRegion, index: index.rawValue)
    }

    func setVertexBuffer<T>(_ value: T, index: Int) {
        let allocation = frameAllocator.allocate(size: MemoryLayout<T>.stride)!
        allocation.write(value: value)

        bindVertexBuffer(allocation, index: index)
    }

    func setVertexBuffer<T, U: RawRepresentable>(_ value: T, index: U) where U.RawValue == Int {
        setVertexBuffer(value, index: index.rawValue)
    }

    func setVertexBuffer<T>(_ value: [T], index: Int) {
        let allocation = frameAllocator.allocate(size: value.byteLength)!
        allocation.write(from: value)

        bindVertexBuffer(allocation, index: index)
    }

    func setVertexBuffer<T, U: RawRepresentable>(_ value: [T], index: U) where U.RawValue == Int {
        setVertexBuffer(value, index: index.rawValue)
    }

    // Fragment
    func bindFragmentBuffer(_ binding: GpuBufferBinding, index: Int) {
        bindBuffer(type: .fragment, newBinding: binding, index: index)
    }

    func bindFragmentBuffer(_ bufferRegion: GpuBufferRegion, offset: Int = 0, index: Int) {
        let binding = bufferRegion.binding(at: offset)
        bindBuffer(type: .fragment, newBinding: binding, index: index)
    }

    func bindFragmentBuffer<U: RawRepresentable>(_ bufferRegion: GpuBufferRegion, index: U) where U.RawValue == Int {
        bindFragmentBuffer(bufferRegion, index: index.rawValue)
    }

    func setFragmentBuffer<T>(_ value: T, index: Int) {
        let allocation = frameAllocator.allocate(size: MemoryLayout<T>.stride)!
        allocation.write(value: value)

        bindFragmentBuffer(allocation, index: index)
    }

    func setFragmentBuffer<T, U: RawRepresentable>(_ value: T, index: U) where U.RawValue == Int {
        setFragmentBuffer(value, index: index.rawValue)
    }

    func setFragmentBuffer<T>(_ value: [T], index: Int) {
        let allocation = frameAllocator.allocate(size: value.byteLength)!
        allocation.write(from: value)

        bindFragmentBuffer(allocation, index: index)
    }

    func setFragmentBuffer<T, U: RawRepresentable>(_ value: [T], index: U) where U.RawValue == Int {
        setFragmentBuffer(value, index: index.rawValue)
    }
}
