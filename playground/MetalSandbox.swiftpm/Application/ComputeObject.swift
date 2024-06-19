import MetalKit

class ComputeObject {
    let pipelineStateFactory: MetalPipelineStateFactory
    let resourceFactory: MetalResourceFactory
    lazy var computePipelineState: MTLComputePipelineState = uninitialized()
    lazy var bufferA: MTLBuffer = uninitialized()
    lazy var bufferB: MTLBuffer = uninitialized()
    lazy var bufferResult: MTLBuffer = uninitialized()
    
    init (
        pipelineStateFactory: MetalPipelineStateFactory, 
        resourceFactory: MetalResourceFactory
    ){
        self.pipelineStateFactory = pipelineStateFactory
        self.resourceFactory = resourceFactory
    }
    
    func build() {
        computePipelineState = {
            let descriptor = MTLComputePipelineDescriptor()
            descriptor.computeFunction = pipelineStateFactory.findFunction(by: .AddArrayComputeFunction)
            return pipelineStateFactory.makeComputePipelineState(descriptor)
        }()
        
        let data1: [Float] = [0.1, 0.2, 0.3]
        let data2: [Float] = [0.4, 0.5, 0.6]
        
        bufferA = resourceFactory.makeBuffer(data: data1, options: .storageModeShared)
        bufferB = resourceFactory.makeBuffer(data: data2, options: .storageModeShared)
        bufferResult = resourceFactory.makeBuffer(length: data1.byteLength, options: .storageModeShared)
    }
        
    func dispatch(encoder: MTLComputeCommandEncoder) {
        encoder.setComputePipelineState(computePipelineState)
        encoder.setBuffer(bufferA, offset: 0, index: 0)
        encoder.setBuffer(bufferB, offset: 0, index: 1)
        encoder.setBuffer(bufferResult, offset: 0, index: 2)
        
        //スレッドグループの数、スレッドグループ内のスレッドの数を設定。これにより並列で実行される演算数が決定される
        let width = 64
        let threadsPerGroup = MTLSize(width: width, height: 1, depth: 1)
        let numThreadgroups = MTLSize(width: (3 + width - 1) / width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
    }
    
    func out() -> [Float] {
        let bufferSize = 3
        let rawbufferSize = MemoryLayout<Float>.stride * bufferSize
        let rawPointer = bufferResult.contents()
        let typedPointer = rawPointer.bindMemory(to: Float.self, capacity: rawbufferSize)
        let bufferedPointer = UnsafeBufferPointer(start: typedPointer, count: bufferSize)
        return Array(bufferedPointer)
    }
}
