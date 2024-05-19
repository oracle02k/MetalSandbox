import CoreFoundation

protocol RendererDebugger
{
    var gpuTime: CFTimeInterval { get set }
    var viewWidth: Int { get set }
    var viewHeight: Int { get set }
}
