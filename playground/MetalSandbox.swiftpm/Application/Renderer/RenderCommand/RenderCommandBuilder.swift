import Metal

class RenderCommandBuilder {
    private let frameAllocator: GpuFrameAllocator
    private let renderCommandRepository: RenderCommandRepository
    private let functions: ShaderFunctions
    private let renderPipelineStateBuilder: RenderPipelineStateBuilder
    private var renderPipelineDescriptor = MTLRenderPipelineDescriptor()
    
    init(
        frameAllocator: GpuFrameAllocator, 
        renderCommandRepository: RenderCommandRepository,
        functions: ShaderFunctions,
        renderPipelineStateBuilder: RenderPipelineStateBuilder
    ){
        self.frameAllocator = frameAllocator
        self.renderCommandRepository = renderCommandRepository
        self.functions = functions
        self.renderPipelineStateBuilder = renderPipelineStateBuilder
    }
    
    func local(_ body:(RenderCommandBuilder)->Void){
        let backup = backupPipelineDescriptor()
        body(self)
        restorePipelineDescriptor(backup)
    }
    
    func setVertexBuffer<T, U: RawRepresentable>(value: T, index:U) where U.RawValue == Int {
        let allocation = frameAllocator.allocate(size: MemoryLayout<T>.stride)!
        allocation.write(value: value)
        
        renderCommandRepository.append(SetVertexBuffer(
            buffer: allocation.buffer, 
            offset: allocation.offset,
            index: index.rawValue
        ))
    }
    
    func setVertexBuffer<T, U: RawRepresentable>(value: [T], index:U) where U.RawValue == Int {
        let allocation = frameAllocator.allocate(size: value.byteLength)!
        allocation.write(from: value)
        
        renderCommandRepository.append(SetVertexBuffer(
            buffer: allocation.buffer, 
            offset: allocation.offset,
            index: index.rawValue
        ))
    }
    
    func bindVertexBuffer<U: RawRepresentable>(buffer:MTLBuffer, index:U) where U.RawValue == Int {
        renderCommandRepository.append(SetVertexBuffer(
            buffer: buffer, 
            offset: 0,
            index: index.rawValue
        ))
    }
    
    func drawPrimitives(type: MTLPrimitiveType, vertexStart: Int, vertexCount: Int){
        let pso = renderPipelineStateBuilder.build(renderPipelineDescriptor)
        renderCommandRepository.append(
            SetRenderPipelineState(renderPipelineState: pso)
        )
        renderCommandRepository.append(
            DrawPrimitives(type: type, vertexStart: vertexStart, vertexCount: vertexCount)
        )
    }
    
    func setFragmentTexture(_ texture: MTLTexture, index: Int){
        renderCommandRepository.append(
            SetFragmentTexture(texture: texture, index: index)
        )
    }
    
    func backupPipelineDescriptor() -> MTLRenderPipelineDescriptor {
        return renderPipelineDescriptor.copy() as! MTLRenderPipelineDescriptor
    }
    
    func restorePipelineDescriptor(_ descriptor: MTLRenderPipelineDescriptor){
        renderPipelineDescriptor = descriptor.copy() as! MTLRenderPipelineDescriptor
    }
    
    func withRenderPipelineDescriptor(_ body: (MTLRenderPipelineDescriptor)->Void){
        body(renderPipelineDescriptor)
    }
    
    func findFunction(by name: ShaderFunctions.FunctionTable) -> MTLFunction {
        return functions.find(by: name)
    }
}
