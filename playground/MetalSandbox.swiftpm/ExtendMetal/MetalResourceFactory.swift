import MetalKit

class MetalResourceFactory {
    private let device: MTLDevice
    
    init(_ device: MTLDevice) {
        self.device = device
        Logger.log(device.name)
    }
    
    func makeBuffer<T>(data: [T], options: MTLResourceOptions) -> MTLBuffer{
        return data.withUnsafeBytes {
            guard let buffer = device.makeBuffer(bytes: $0.baseAddress!, length: data.byteLength, options: options) else {
                appFatalError("failed to make buffer.")
            }
            return buffer;
        }
    }
    
    func makeBuffer(length: Int, options: MTLResourceOptions) -> MTLBuffer{
            guard let buffer = device.makeBuffer(length: length, options: options) else {
                appFatalError("failed to make buffer.")
            }
            return buffer;
    }
    
    func makeTexture(_ descriptor: MTLTextureDescriptor) -> MTLTexture {
        Logger.log(device.name)
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            appFatalError("failed to make texture.")
        }
        return texture
    }
}
