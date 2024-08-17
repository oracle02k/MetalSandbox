import Swinject

class DIContainer {
    private static let container = Container()
    
    static func register(){
        // Application
        container.register(Application.self) { r in
            Application(gpu: r.resolve(GpuContext.self)!)
        }.inObjectScope(.container)
        
        // Debug
        container.register(DebugVM.self) { _ in
            DebugVM()
        }.inObjectScope(.container)
        container.register(AppDebuggerBindVM.self) { r in
            AppDebuggerBindVM(r.resolve(DebugVM.self)!)
        }.inObjectScope(.container)
        
        // Metal Device
        container.register(MetalDeviceResolver.self) { _ in
            MetalDeviceResolver()
        }.inObjectScope(.container)
        container.register(GpuContext.self) { r in
            GpuContext(resolver:r.resolve(MetalDeviceResolver.self)!)
        }.inObjectScope(.container)
        
        // Renderer Common
        container.register(FrameBuffer.self) { _ in FrameBuffer() }
        container.register(IndexedMesh.Factory.self) { r in
            IndexedMesh.Factory(gpu: r.resolve(GpuContext.self)!)
        }
        container.register(ScreenRenderPass.self) { r in 
            ScreenRenderPass(
                with: r.resolve(GpuContext.self)!,
                indexedMeshFactory: r.resolve(IndexedMesh.Factory.self)!
            )
        }
        container.register(ViewRenderPass.self) { r in 
            ViewRenderPass(with: r.resolve(ScreenRenderPass.self)!)
        }
        
        // TriangleRenderPipeline
        container.register(TriangleRenderPipeline.self) { r in
            TriangleRenderPipeline(
                gpu: r.resolve(GpuContext.self)!,
                triangleRenderPass: r.resolve(TriangleRenderPass.self)!,
                viewRenderPass: r.resolve(ViewRenderPass.self)!
            )
        }
        container.register(TriangleRenderPass.self) { r in
            TriangleRenderPass(
                with: r.resolve(GpuContext.self)!,
                functions: r.resolve(TriangleRenderPass.Functions.self)!
            )
        }
        container.register(TriangleRenderPass.Functions.self){ r in
            TriangleRenderPass.Functions(with: r.resolve(GpuContext.self)!)
        }
        
        // IndirectRenderPipeline
        container.register(IndirectRenderPipeline.self) { r in
            IndirectRenderPipeline(
                gpu: r.resolve(GpuContext.self)!,
                indirectRenderPass: r.resolve(IndirectRenderPass.self)!,
                viewRenderPass: r.resolve(ViewRenderPass.self)!,
                frameBuffer: r.resolve(FrameBuffer.self)!
            )
        }
        container.register(IndirectRenderPass.self) { r in
            IndirectRenderPass(
                with: r.resolve(GpuContext.self)!,
                functions: r.resolve(IndirectRenderPass.Functions.self)!
            )
        }
        container.register(IndirectRenderPass.Functions.self){ r in
            IndirectRenderPass.Functions(with: r.resolve(GpuContext.self)!)
        }
        
        // TileRenderPipeline
        container.register(TileRenderPipeline.self) { r in
            TileRenderPipeline(
                gpu: r.resolve(GpuContext.self)!,
                tileRenderPass: r.resolve(TileRenderPass.self)!,
                viewRenderPass: r.resolve(ViewRenderPass.self)!,
                frameBuffer: r.resolve(FrameBuffer.self)!
            )
        }
        container.register(TileRenderPass.self) { r in
            TileRenderPass(
                with: r.resolve(GpuContext.self)!,
                functions: r.resolve(TileRenderPass.Functions.self)!
            )
        }
        container.register(TileRenderPass.Functions.self){ r in
            TileRenderPass.Functions(with: r.resolve(GpuContext.self)!)
        }
        
        // RasterOrderGroupRenderPipeline
        container.register(RasterOrderGroupRenderPipeline.self) { r in
            RasterOrderGroupRenderPipeline(
                gpu: r.resolve(GpuContext.self)!,
                rasterOrderGroupRenderPass: r.resolve(RasterOrderGroupRenderPass.self)!,
                viewRenderPass: r.resolve(ViewRenderPass.self)!
            )
        }
        container.register(RasterOrderGroupRenderPass.self) { r in
            RasterOrderGroupRenderPass(
                with: r.resolve(GpuContext.self)!,
                indexedMeshFactory: r.resolve(IndexedMesh.Factory.self)!,
                functions: r.resolve(RasterOrderGroupRenderPass.Functions.self)!
            )
        }
        container.register(RasterOrderGroupRenderPass.Functions.self){ r in
            RasterOrderGroupRenderPass.Functions(with: r.resolve(GpuContext.self)!)
        }
    }
    
    static func resolve<T>(_ type: T.Type = T.self) -> T {
        return container.resolve(type.self)!
    }
}
