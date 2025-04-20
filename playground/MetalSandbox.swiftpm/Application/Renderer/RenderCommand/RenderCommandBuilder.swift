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
    private let vertexBufferViews: FixedArray<GpuBufferView?> = .init(repeating: nil, count: 8)
    private let fragmentBufferViews: FixedArray<GpuBufferView?> = .init(repeating: nil, count: 8)
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
    
    func allocFrameHeapBlock<T>(_ type:T.Type, length:Int = 1) -> GpuTransientHeapBlock {
        return frameAllocator.allocate(size: MemoryLayout<T>.stride * length)!
    }
}

extension RenderCommandBuilder{
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
    
    private func bindBuffer(type: BindType, heapBlock: GpuTransientHeapBlock, offset: Int, index: Int) {
        let newView = heapBlock.makeView(offset: offset)
        let (views, heaps) = switch type {
            case .vertex: (vertexBufferViews, vertexHeapBlocks)
            case .fragment: (fragmentBufferViews, fragmentHeapBlocks)
        }
        
        defer {
            heaps[index] = heapBlock
            views[index] = newView
        }
        
        guard let currentView = views[index] else {
            renderCommandRepository.append(type.setBufferCommand(newView.buffer, offset: newView.offset, index: index))
            return
        }
        
        if currentView == newView {
            return
        }
        
        if currentView.isSameBuffer(as: newView) {
            renderCommandRepository.append(type.setOffsetCommand(newView.offset, index:index))
            return
        }
        
        renderCommandRepository.append(type.setBufferCommand(newView.buffer, offset: newView.offset, index: index))
    }
    
    func setBufferOffset(type: BindType, offset: Int, index: Int) {
        let (views, heaps) = switch type {
            case .vertex: (vertexBufferViews, vertexHeapBlocks)
            case .fragment: (fragmentBufferViews, fragmentHeapBlocks)
        }
        
        // Validation: buffer must be bound
        guard 
            let heapBlock = heaps[index],
            let currentView = views[index]
        else {
            appFatalError("No buffer bound at index: \(index)")
        }
        
        // Validation: offset must be within buffer size
        guard offset < heapBlock.size else {
            appFatalError("Invalid offset. Requested offset: \(offset) exceeds buffer size: \(heapBlock.size).")
        }
        
        let newView = heapBlock.makeView(offset: offset)
        guard newView.offset != currentView.offset else {
            return // No update needed
        }
        
        // Offset-only update
        renderCommandRepository.append(
            type.setOffsetCommand(newView.offset, index: index)
        )
        
        views[index] = newView
    }
    
    func bindVertexBuffer(_ heapBlock: GpuTransientHeapBlock, offset: Int = 0, index: Int) {
        bindBuffer(type: .vertex, heapBlock: heapBlock, offset:offset, index: index)
    }
    
    func bindVertexBuffer<U: RawRepresentable>(_ heapBlock:GpuTransientHeapBlock, index: U) where U.RawValue == Int {
        bindVertexBuffer(heapBlock, index: index.rawValue)
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
    
    func setVertexBufferOffset(_ offset: Int, index: Int) {
        setBufferOffset(type: .vertex, offset: offset, index: index)
    }
    
    func setVertexBufferOffset<U: RawRepresentable>(_ offset:Int,  index: U) where U.RawValue == Int {
        setVertexBufferOffset(offset, index: index.rawValue)
    }
    
    func bindFragmentBuffer(_ heapBlock: GpuTransientHeapBlock, offset: Int = 0, index: Int) {
        bindBuffer(type: .fragment, heapBlock: heapBlock, offset:offset, index: index)
    }
    
    func bindFragmentBuffer<U: RawRepresentable>(_ heapBlock:GpuTransientHeapBlock, index: U) where U.RawValue == Int {
        bindFragmentBuffer(heapBlock, index: index.rawValue)
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
    
    func setFragmentBufferOffset(_ offset: Int, index: Int) {
        setBufferOffset(type: .fragment, offset: offset, index: index)
    }
    
    func setFragmentBufferOffset<U: RawRepresentable>(_ offset:Int,  index: U) where U.RawValue == Int {
        setFragmentBufferOffset(offset, index: index.rawValue)
    }
}
