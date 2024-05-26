import SwiftUI

class RenderPipelineStateContainer {
    private let device: MTLDevice
    private var container = [MTLRenderPipelineState]()
    
    init (device: MTLDevice) {
        self.device = device
        self.container = []
    }
    
    func buildAndRegister(from descriptor: MTLRenderPipelineDescriptor) -> Int {
        do {
            let pso = try device.makeRenderPipelineState(descriptor: descriptor)
            container.append(pso)
        } catch {
            appFatalError("failed to make render pipeline state.")
        }
        return container.count - 1
    }
    
    func find(by id: Int) -> MTLRenderPipelineState {
        return container[id]
    }
}
