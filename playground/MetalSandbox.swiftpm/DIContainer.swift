import Swinject

class DIContainer {
    private static let container = Container()

    static func register() {
        // Metal Device
        container.register(MetalDeviceResolver.self) { _ in
            MetalDeviceResolver()
        }.inObjectScope(.container)
        container.register(GpuContext.self) { r in
            GpuContext(resolver: r.resolve(MetalDeviceResolver.self)!)
        }.inObjectScope(.container)

        // GpuCounterSampler
        container.register(GpuCounterSampler.self) { r in
            GpuCounterSampler(counterSampleContainer: r.resolve(GpuCounterSampleContainer.self)!)
        }.inObjectScope(.container)
        container.register(GpuCounterSampleContainer.self) { r in
            GpuCounterSampleContainer(
                gpu: r.resolve(GpuContext.self)!,
                sampleItemRepository: r.resolve(GpuCounterSampleItemRepository.self)!
            )
        }.inObjectScope(.container)
        container.register(GpuCounterSampleItemRepository.self) { _ in
            GpuCounterSampleItemRepository()
        }.inObjectScope(.container)

        // FrameStatsReporter
        container.register(FrameStatsReporter.self) { r in
            FrameStatsReporter(repository: r.resolve(FrameStatsReportRepository.self)!)
        }.inObjectScope(.container)
        container.register(FrameStatsReportRepository.self) { _ in
            FrameStatsReportRepository()
        }.inObjectScope(.container)

        // StatsModel
        container.register(StatsModel.self) { r in
            StatsModel(repository: r.resolve(FrameStatsReportRepository.self)!)
        }

        // Application
        container.register(Application.self) { r in
            Application(
                gpu: r.resolve(GpuContext.self)!,
                frameStatsReporter: r.resolve(FrameStatsReporter.self)!,
                gpuCounterSampler: r.resolve(GpuCounterSampler.self)!
            )
        }.inObjectScope(.container)

        // Debug
        container.register(DebugVM.self) { _ in
            DebugVM()
        }.inObjectScope(.container)
        container.register(AppDebuggerBindVM.self) { r in
            AppDebuggerBindVM(r.resolve(DebugVM.self)!)
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
        container.register(TrianglePipeline.self) { r in
            TrianglePipeline(
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
        container.register(TriangleRenderPass.Functions.self) { r in
            TriangleRenderPass.Functions(with: r.resolve(GpuContext.self)!)
        }

        // IndirectPipeline
        container.register(IndirectPipeline.self) { r in
            IndirectPipeline(
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
        container.register(IndirectRenderPass.Functions.self) { r in
            IndirectRenderPass.Functions(with: r.resolve(GpuContext.self)!)
        }

        // TilePipeline
        container.register(TilePipeline.self) { r in
            TilePipeline(
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
        container.register(TileRenderPass.Functions.self) { r in
            TileRenderPass.Functions(with: r.resolve(GpuContext.self)!)
        }

        // RasterOrderGroupPipeline
        container.register(RasterOrderGroupPipeline.self) { r in
            RasterOrderGroupPipeline(
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
        container.register(RasterOrderGroupRenderPass.Functions.self) { r in
            RasterOrderGroupRenderPass.Functions(with: r.resolve(GpuContext.self)!)
        }

        // LifegamePipeline
        container.register(LifegamePipeline.self) { r in
            LifegamePipeline(
                gpu: r.resolve(GpuContext.self)!,
                lifegameRenderPass: r.resolve(LifegameRenderPass.self)!,
                lifegameComputePass: r.resolve(LifegameComputePass.self)!,
                viewRenderPass: r.resolve(ViewRenderPass.self)!,
                lifegame: r.resolve(LifegameProc.self)!
            )
        }
        container.register(LifegameRenderPass.self) { r in
            LifegameRenderPass(
                with: r.resolve(GpuContext.self)!,
                functions: r.resolve(LifegameRenderPass.Functions.self)!
            )
        }
        container.register(LifegameRenderPass.Functions.self) { r in
            LifegameRenderPass.Functions(with: r.resolve(GpuContext.self)!)
        }
        container.register(LifegameComputePass.self) { r in
            LifegameComputePass(
                with: r.resolve(GpuContext.self)!,
                functions: r.resolve(LifegameComputePass.Functions.self)!
            )
        }
        container.register(LifegameComputePass.Functions.self) { r in
            LifegameComputePass.Functions(with: r.resolve(GpuContext.self)!)
        }
        container.register(LifegameProc.self) { _ in LifegameProc() }
    }

    static func resolve<T>(_ type: T.Type = T.self) -> T {
        return container.resolve(type.self)!
    }
}
