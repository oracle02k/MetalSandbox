import Metal

class RenderCommandEncoderFactory<T: RenderPassConfigurationProvider> {
    typealias DescriptorSpec = T.DescriptorSpec
    private let renderPipelines: T.RenderPipelines

    init(using renderPipelines: T.RenderPipelines) {
        self.renderPipelines = renderPipelines
    }

    func makeEncoder(
        from descriptor: MTLRenderPassDescriptor,
        using commandBuffer: MTLCommandBuffer,
        counterSampler: CounterSampler? = nil,
        label: String = T.Name
    ) -> RenderCommandEncoder<T> {
        guard DescriptorSpec().isSatisfiedBy(descriptor) else {
            appFatalError("error descriptor")
        }

        counterSampler?.attachToRenderPass(descriptor: descriptor, name: label)
        let metalEncoder = commandBuffer.makeRenderCommandEncoderWithSafe(descriptor: descriptor)

        return RenderCommandEncoder(encoder: metalEncoder, renderPipelines: renderPipelines)
    }
}
