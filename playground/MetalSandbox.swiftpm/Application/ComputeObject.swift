import MetalKit

class ComputeObject {
    let pipelineStateFactory: MetalPipelineStateFactory
    let resourceFactory: MetalResourceFactory
    lazy var computePipelineState: MTLComputePipelineState = uninitialized()
    lazy var bufferA: MTLBuffer = uninitialized()
    lazy var bufferB: MTLBuffer = uninitialized()
    lazy var bufferResult: MTLBuffer = uninitialized()
    let elementNum = 100

    init (
        pipelineStateFactory: MetalPipelineStateFactory,
        resourceFactory: MetalResourceFactory
    ) {
        self.pipelineStateFactory = pipelineStateFactory
        self.resourceFactory = resourceFactory
    }

    func build() {
        computePipelineState = {
            let descriptor = MTLComputePipelineDescriptor()
            descriptor.computeFunction = pipelineStateFactory.findFunction(by: .AddArrayComputeFunction)
            return pipelineStateFactory.makeComputePipelineState(descriptor)
        }()

        bufferA = generateRandomFloatData(count: elementNum)
        bufferB = generateRandomFloatData(count: elementNum)
        bufferResult = resourceFactory.makeBuffer(length: MemoryLayout<Float>.stride * elementNum, options: .storageModeShared)
    }

    func dispatch(encoder: MTLComputeCommandEncoder) {
        encoder.setComputePipelineState(computePipelineState)
        encoder.setBuffer(bufferA, offset: 0, index: 0)
        encoder.setBuffer(bufferB, offset: 0, index: 1)
        encoder.setBuffer(bufferResult, offset: 0, index: 2)

        // スレッドグループの数、スレッドグループ内のスレッドの数を設定。これにより並列で実行される演算数が決定される
        /*
         let width = 64
         let threadsPerGroup = MTLSize(width: width, height: 1, depth: 1)
         let numThreadgroups = MTLSize(width: (3 + width - 1) / width, height: 1, depth: 1)
         encoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
         */

        let gridSize = MTLSizeMake(elementNum, 1, 1) // 1Dgrid
        var threadGroupSize = computePipelineState.maxTotalThreadsPerThreadgroup
        if threadGroupSize > elementNum {
            threadGroupSize = elementNum
        }
        let threadgroupSize = MTLSizeMake(threadGroupSize, 1, 1)
        encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
    }

    func generateRandomFloatData(count: Int) -> MTLBuffer {
        var data: [Float] = []
        for _ in 0..<count {
            data.append(Float.random(in: 0.0...1.0))
        }

        return resourceFactory.makeBuffer(data: data, options: .storageModeShared)
    }

    func verifyResult() {
        let aBuffer: [Float] = bufferA.bindArray(length: elementNum)
        let bBuffer: [Float] = bufferB.bindArray(length: elementNum)
        let result: [Float] = bufferResult.bindArray(length: elementNum)

        for i in 0..<elementNum {
            let cpuResult = aBuffer[i] + bBuffer[i]
            if result[i] != cpuResult {
                Debug.frameLog("Compute ERROR: index=\(i) gpu=\(result[i]) vs cpu=\(cpuResult)")
            }
        }
        Debug.frameLog("Compute results as expected\n")
    }
}
