import Swinject

class DIContainer {
    private static let container = Container()
    
    static func register(){
        container.register(MetalDeviceResolver.self) { _ in
            MetalDeviceResolver()
        }.inObjectScope(.container)
        container.register(GpuContext.self) { r in
            GpuContext(resolver:r.resolve(MetalDeviceResolver.self)!)
        }.inObjectScope(.container)
        
        container.register(FunctionContainer<TriangleRenderPass.Function>.self){ r in
            FunctionContainer<TriangleRenderPass.Function>(with: r.resolve(GpuContext.self)!)
        }
        container.register(TriangleRenderPass.self) { r in
            TriangleRenderPass(
                with: r.resolve(GpuContext.self)!,
                functions: r.resolve(FunctionContainer<TriangleRenderPass.Function>.self)!
            )
        }
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
        
        container.register(TriangleRenderPipeline.self) { r in
            TriangleRenderPipeline(
                gpu: r.resolve(GpuContext.self)!,
                triangleRenderPass: r.resolve(TriangleRenderPass.self)!,
                viewRenderPass: r.resolve(ViewRenderPass.self)!
            )
        }
    }
    
    static func resolve<T>(_ type: T.Type = T.self) -> T {
        return container.resolve(type.self)!
    }
}
