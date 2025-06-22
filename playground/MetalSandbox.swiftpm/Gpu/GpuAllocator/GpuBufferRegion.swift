import Metal

protocol GpuBufferRegion {
    var buffer: MTLBuffer { get }
    var begin: Int { get }
    var end: Int { get }
    var size: Int { get }
    
    func contains(offset: Int) -> Bool
    func binding(at offset: Int) -> GpuBufferBinding
}

extension GpuBufferRegion {
    func contains(offset: Int) -> Bool {
        return 0 <= offset && offset < end
    }
    func binding(at offset: Int = 0) -> GpuBufferBinding {
        guard contains(offset: offset) else {
            appFatalError("binding offset \(offset) is out of bounds for region [\(begin)..<\(end)]")
        }
        
        return GpuBufferBinding(buffer: buffer, offset: begin + offset)
    }
}
