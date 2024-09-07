import MetalKit

class LifegamePipeline: FramePipeline {
    private let gpu: GpuContext
    private let lifegameRenderPass: LifegameRenderPass
    private let lifegameComputePass: LifegameComputePass
    private let viewRenderPass: ViewRenderPass
    private let lifegame: Lifegame
    private lazy var offscreenTexture: MTLTexture = uninitialized()
    private lazy var useCompute:Bool = uninitialized()
    
    init(gpu: GpuContext, 
         lifegameRenderPass: LifegameRenderPass, 
         lifegameComputePass: LifegameComputePass,
         viewRenderPass: ViewRenderPass,
         lifegame:Lifegame)
    {
        self.gpu = gpu
        self.lifegameRenderPass = lifegameRenderPass
        self.lifegameComputePass = lifegameComputePass
        self.viewRenderPass = viewRenderPass
        self.lifegame = lifegame
    }
    
    func build(width:Int, height:Int, useCompute:Bool) {
        self.useCompute = useCompute
        
        if useCompute {
            lifegameComputePass.build(width: width, height: height)
            gpu.doCommand { commandBuffer in
                lifegameComputePass.reset(using: commandBuffer)
                commandBuffer.commit()
            }
        }else{
            lifegame.reset(width: width, height: height)
        }
        
        lifegameRenderPass.build(width:width, height: height)
        viewRenderPass.build()
        
        changeSize(viewportSize: .init(width: 760, height: 760))
    }
    
    func changeSize(viewportSize: CGSize) {
        offscreenTexture = {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2D
            descriptor.width = Int(viewportSize.width)
            descriptor.height = Int(viewportSize.height)
            descriptor.pixelFormat = .bgra8Unorm
            descriptor.usage = [.renderTarget, .shaderRead]
            return gpu.makeTexture(descriptor)
        }()
    }
    
    func update(
        drawTo metalLayer: CAMetalLayer,
        logTo frameLogger: FrameStatisticsLogger?,
        _ frameComplited: @escaping ()->Void
    ) {
        lazy var fieldBuffer: MTLBuffer = uninitialized()
        
        if !useCompute {
            lifegame.update()
            fieldBuffer = gpu.makeBuffer(data: lifegame.field.map{UInt16($0)}, options: [])
        }
    
        let colorTarget = MTLRenderPassColorAttachmentDescriptor()
        colorTarget.texture = offscreenTexture
        colorTarget.loadAction = .clear
        colorTarget.clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        colorTarget.storeAction = .store
        
        gpu.doCommand { commandBuffer in
            if useCompute {
                fieldBuffer = lifegameComputePass.update(using: commandBuffer)
            }
            lifegameRenderPass.draw(fieldBuffer: fieldBuffer, toColor: colorTarget, using: commandBuffer)
            viewRenderPass.draw(to: metalLayer, using: commandBuffer, source: offscreenTexture)
            commandBuffer.addCompletedHandler { [self] _ in
                frameLogger?.addCommandBufferLog(.init(
                    label: "lifegame pipeline",
                    commandBuffer: commandBuffer,
                    details: [
                        lifegameRenderPass.debugFrameStatus(),
                        viewRenderPass.debugFrameStatus()
                    ]
                ))
                frameComplited()
            }
            commandBuffer.commit()
        }
    }
}
