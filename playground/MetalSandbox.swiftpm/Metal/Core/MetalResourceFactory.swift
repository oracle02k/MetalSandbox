import MetalKit

class TypedBuffer<T> {
    let rawBuffer: MTLBuffer
    let count: Int
    let bufferedPointer: UnsafeMutableBufferPointer<T>
    
    init(rawBuffer: MTLBuffer, count: Int) {
        self.rawBuffer = rawBuffer
        self.count = count
        let rawbufferSize = MemoryLayout<T>.stride * count
        let rawPointer = rawBuffer.contents()
        let typedPointer = rawPointer.bindMemory(to: T.self, capacity: rawbufferSize)
        bufferedPointer = UnsafeMutableBufferPointer(start: typedPointer, count: count)
    }
    
    var contents: T { 
        get { bufferedPointer[0] }
        set { bufferedPointer[0] = newValue }
    }
    
    subscript(index: Int) -> T {
        get { bufferedPointer[index] }
        set { bufferedPointer[index] = newValue }
    }
    
    func write(index: Int, data:T) {
        bufferedPointer[index] = data
    }
 }

class MetalResourceFactory {
         let device: MTLDevice

    init(_ device: MTLDevice) {
        self.device = device
    }
    
    func makeTypedBuffer<T>(elementCount: Int = 1, options: MTLResourceOptions) -> TypedBuffer<T> {
        let rawlength = MemoryLayout<T>.stride * elementCount
        let rawBuffer = makeBuffer(length: rawlength, options: options)
        return TypedBuffer<T>(rawBuffer: rawBuffer, count: elementCount)
    }

    func makeBuffer<T>(data: [T], options: MTLResourceOptions) -> MTLBuffer {
        return data.withUnsafeBytes {
            guard let buffer = device.makeBuffer(bytes: $0.baseAddress!, length: data.byteLength, options: options) else {
                appFatalError("failed to make buffer.")
            }
            return buffer
        }
    }

    func makeBuffer(length: Int, options: MTLResourceOptions) -> MTLBuffer {
        guard let buffer = device.makeBuffer(length: length, options: options) else {
            appFatalError("failed to make buffer.")
        }
        return buffer
    }

    func makeTexture(_ descriptor: MTLTextureDescriptor) -> MTLTexture {
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            appFatalError("failed to make texture.")
        }
        return texture
    }
}
