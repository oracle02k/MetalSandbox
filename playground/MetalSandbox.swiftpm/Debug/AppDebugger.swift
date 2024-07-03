import CoreFoundation

protocol AppDebugger {
    var initLogText: String { get }
    var frameLogText: String { get }

    func allClear()
    func frameClear()
    func initLog(_ message: String)
    func frameLog(_ message: String)
    func flush()
}
