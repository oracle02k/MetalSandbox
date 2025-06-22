import Swinject

class DIContainer {
    private static let container = Container()
    
    static func register() {
        // Metal Device
        container.register(MetalDeviceResolver.self) { _ in
            MetalDeviceResolver()
        }.inObjectScope(.container)
        
        // Gpu Context
        container.register(GpuContext.self) { r in
            GpuContext(deviceResolver: r.resolve(MetalDeviceResolver.self)!)
        }.inObjectScope(.transient)
        
        // CounterSampler
        container.register(GpuCounterSampler.self) { r in
            GpuCounterSampler(
                counterSampleSummaryRepository: r.resolve(GpuCounterSampleSummaryRepository.self)!,
                counterSampleReportRepository: r.resolve(GpuCounterSampleReportRepository.self)!
            )
        }.inObjectScope(.container)
        container.register(GpuCounterSampleSummaryRepository.self) { _ in
            GpuCounterSampleSummaryRepository()
        }.inObjectScope(.container)
        container.register(GpuCounterSampleReportRepository.self) { _ in
            GpuCounterSampleReportRepository()
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
                counterSampleSummaryRepository: r.resolve(GpuCounterSampleSummaryRepository.self)!,
                counterSampleReportRepository: r.resolve(GpuCounterSampleReportRepository.self)!
            )
        }
        
        //Application
        container.register(Application.self) { r in
            Application(gpu: r.resolve(GpuContext.self)!)
        }.inObjectScope(.container)
    }
    
    static func resolve<T>(_ type: T.Type = T.self) -> T {
        return container.resolve(type.self)!
    }
}
