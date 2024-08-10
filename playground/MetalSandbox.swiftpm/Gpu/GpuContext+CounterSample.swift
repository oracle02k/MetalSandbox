import MetalKit

extension GpuContext {
    func checkCounterSample() -> [MTLCounterSamplingPoint] {
        let boundaryNames = ["atStageBoundary",
                             "atDrawBoundary",
                             "atBlitBoundary",
                             "atDispatchBoundary",
                             "atTileDispatchBoundary"]

        let allBoundaries: [MTLCounterSamplingPoint] = [.atStageBoundary,
                                                        .atDrawBoundary,
                                                        .atBlitBoundary,
                                                        .atDispatchBoundary,
                                                        .atTileDispatchBoundary]

        print("The GPU device supports the following sampling boundary/ies: [", terminator: "")
        var boundaries = [MTLCounterSamplingPoint]()

        for index in 0..<boundaryNames.count {
            let boundary = allBoundaries[index]
            if device.supportsCounterSampling(boundary) {
                if boundaries.count >= 1 {
                    // Prefix the boundary's name with a comma and a space.
                    print(", ", terminator: "")
                }
                // Print the boundary's name.
                print("\(boundaryNames[index])", terminator: "")
                // Add the boundary to the return-value array.
                boundaries.append(boundary)
            }
        }
        // Finish printing the line that lists the boundaries the GPU device supports.
        // Example: "The GPU device supports the following sampling boundaries: [atStageBoundary]"
        print("]")

        return boundaries
    }

    func makeCounterSampleBuffer(_ sampleSet: MTLCommonCounterSet) -> MTLCounterSampleBuffer? {
        var counterSet: MTLCounterSet?

        for set in device.counterSets! {
            if set.name.caseInsensitiveCompare(sampleSet.rawValue) == .orderedSame {
                counterSet = set
                break
            }
        }

        guard let counterSet = counterSet else {
            return nil
        }

        // Create and configure a descriptor for the counter sample buffer.
        let descriptor = MTLCounterSampleBufferDescriptor()
        // This counter set instance belongs to the `device` instance.
        descriptor.counterSet = counterSet
        // Set the buffer to use shared memory so the CPU and GPU can directly access its contents.
        descriptor.storageMode = .shared
        // Set the sample count to 4, to make room for the:
        // – Vertex stage's start time
        // – Vertex stage's completion time
        // – Fragment stage's start time
        // – Fragment stage's completion time
        descriptor.sampleCount = 6
        // Create the sample buffer by passing the descriptor to the device's factory method.
        guard let buffer = try? device.makeCounterSampleBuffer(descriptor: descriptor) else {
            appFatalError("Device failed to create a counter sample buffer.")
        }

        return buffer
    }

    func attachCounterSample(to descriptor: MTLRenderPassDescriptor, index: Int) -> MTLCounterSampleBuffer? {
        guard let sampleAttachment = descriptor.sampleBufferAttachments[index] else {
            // appFatalError("sample buffer error.")
            return nil
        }

        guard let counterSampleBuffer = makeCounterSampleBuffer(MTLCommonCounterSet.timestamp) else {
            // appFatalError("sample buffer error.")
            return nil
        }

        sampleAttachment.sampleBuffer = counterSampleBuffer
        sampleAttachment.startOfVertexSampleIndex = 0
        sampleAttachment.endOfVertexSampleIndex = 1
        sampleAttachment.startOfFragmentSampleIndex = 2
        sampleAttachment.endOfFragmentSampleIndex = 3

        return counterSampleBuffer
    }

    func debugCountreSample(from counterSampleBuffer: MTLCounterSampleBuffer?) {
        guard let counterSampleBuffer = counterSampleBuffer else {
            return
        }

        let sampleCount = counterSampleBuffer.sampleCount
        guard let sampleData = try? counterSampleBuffer.resolveCounterRange(0..<sampleCount) else {
            // appFatalError("Device failed to create a counter sample buffer.")
            return
        }

        sampleData.withUnsafeBytes { body in
            let sample = body.bindMemory(to: MTLCounterResultTimestamp.self)
            let vertexInterval = Float(sample[1].timestamp - sample[0].timestamp) / Float(NSEC_PER_MSEC)
            let fragmentInterval = Float(sample[3].timestamp - sample[2].timestamp) / Float(NSEC_PER_MSEC)
            Debug.frameLog(String(format: "VertexTime: %.2fms", vertexInterval))
            Debug.frameLog(String(format: "FragmentTime: %.2fms", fragmentInterval))
        }
    }
}
