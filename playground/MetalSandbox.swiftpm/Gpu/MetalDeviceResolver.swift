import Metal

final class MetalDeviceResolver {
    private lazy var device: MTLDevice = {
        guard let device = MTLCreateSystemDefaultDevice() else {
            appFatalError("GPU not available ")
        }
        
        return device
    }()
    
    func resolve() -> MTLDevice {
        return device
    }
}
