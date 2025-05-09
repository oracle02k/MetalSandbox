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

        // CounterSampler
        container.register(CounterSampler.self) { r in
            CounterSampler(
                counterSampleSummaryRepository: r.resolve(CounterSampleSummaryRepository.self)!,
                counterSampleReportRepository: r.resolve(CounterSampleReportRepository.self)!
            )
        }.inObjectScope(.container)
        container.register(CounterSampleSummaryRepository.self) { _ in
            CounterSampleSummaryRepository()
        }.inObjectScope(.container)
        container.register(CounterSampleReportRepository.self) { _ in
            CounterSampleReportRepository()
        }.inObjectScope(.container)

        // FrameStatsReporter
        container.register(FrameStatsReporter.self) { r in
            FrameStatsReporter(repository: r.resolve(FrameStatsReportRepository.self)!)
        }.inObjectScope(.container)
        container.register(FrameStatsReportRepository.self) { _ in
            FrameStatsReportRepository()
        }.inObjectScope(.container)

        // Stats
        container.register(StatsStore.self) { r in
            StatsStore(
                frameStatsRepository: r.resolve(FrameStatsReportRepository.self)!,
                counterSampleSummaryRepository: r.resolve(CounterSampleSummaryRepository.self)!,
                counterSampleReportRepository: r.resolve(CounterSampleReportRepository.self)!
            )
        }

        // Application
        container.register(Application.self) { r in
            Application(
                gpu: r.resolve(GpuContext.self)!
            )
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

        // Check
        container.register(CheckPipeline.self) { r in
            CheckPipeline(
                gpu: r.resolve(GpuContext.self)!,
                checkComputePass: r.resolve(CheckComputePass.self)!,
                viewRenderPass: r.resolve(ViewRenderPass.self)!
            )
        }
        container.register(CheckComputePass.self) { r in
            CheckComputePass(with: r.resolve(GpuContext.self)!, functions: r.resolve(CheckComputePass.Functions.self)!)
        }
        container.register(CheckComputePass.Functions.self) { r in
            CheckComputePass.Functions(with: r.resolve(GpuContext.self)!)
        }

    }

    static func resolve<T>(_ type: T.Type = T.self) -> T {
        return container.resolve(type.self)!
    }
}
