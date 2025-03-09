import SwiftUI

protocol RenderPassConfigurationProvider {
    static var Name: String { get }
    associatedtype Functions: FunctionContainerProvider
    associatedtype RenderPipelines: RenderPipelineContainer<Self>
    associatedtype RenderPipelineFactory: RenderPipelineFactorizeProvider
    associatedtype DescriptorSpec: RenderPassDescriptorSpecProvider
    associatedtype CommandEncoderFactory: RenderCommandEncoderFactory<Self>
}

protocol RenderPassDescriptorSpecProvider {
    init()
    func isSatisfiedBy(_ descriptor: MTLRenderPassDescriptor) -> Bool
}
