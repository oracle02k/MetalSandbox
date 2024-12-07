import MetalKit

class GpuCounterSampleGroup {
    let label: String
    let container: GpuCounterSampleContainer
    
    init(
        label: String,
        container: GpuCounterSampleContainer
    ){
        self.label = label
        self.container = container
    }
    
    func addSampleRenderInterval(
        of descriptor:MTLRenderPassDescriptor,
        index:Int = 0,
        label: String
    ) -> Bool{
        Logger.log("add Index: \(index)")
        return container.addSampleRenderInterval(
            of: descriptor,
            index: index, 
            groupLabel: self.label,
            sampleLabel: label
        )
    }
    
    func addSampleComputeInterval(
        of descriptor:MTLComputePassDescriptor,
        index:Int = 0,
        label: String
    ) -> Bool{
        return container.addSampleComputeInterval(
            of: descriptor,
            index: index, 
            groupLabel: self.label,
            sampleLabel: label
        )
    }
    
    func resolve() -> [GpuCounterSampleReport] {
        return container.resolve(groupLabel: label)
    }
}
