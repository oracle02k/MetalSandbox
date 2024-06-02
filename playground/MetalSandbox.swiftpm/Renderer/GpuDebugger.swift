import CoreFoundation

protocol GpuDebugger
{
    var gpuTime: CFTimeInterval { get set }
    var viewWidth: Int { get set }
    var viewHeight: Int { get set }
    var log: String { get }
    
    func framInit()
    func addLog(_ message: String)
}
