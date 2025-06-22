import Foundation
import MetalKit

enum SceneType {
    case tile
    case indirect

    func makeScene(gpu: GpuContext) -> SandboxScene {
        return switch self {
        case .tile: TileScene(gpu: gpu)
        case .indirect: IndirectScene(gpu: gpu)
        }
    }
}

final class Application {
    static let ColorPixelFormat: MTLPixelFormat = .bgra8Unorm

    let gpu: GpuContext
    let scene: SandboxScene
    let frameStatsReporter: FrameStatsReporter? = DIContainer.resolve(FrameStatsReporter.self)
    lazy var offscreen: MTLTexture = uninitialized()
    lazy var depthTexture: MTLTexture = uninitialized()

    init(gpu: GpuContext) {
        self.gpu = gpu
        self.scene = SceneType.indirect.makeScene(gpu: self.gpu)
    }

    func build() {
        gpu.build()
        scene.build()

        offscreen = {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2D
            descriptor.width = 320
            descriptor.height = 320
            descriptor.pixelFormat = .bgra8Unorm
            descriptor.usage = [.renderTarget, .shaderRead]
            return gpu.makeTexture(descriptor)
        }()

        depthTexture = {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2D
            descriptor.width = 320
            descriptor.height = 320
            descriptor.pixelFormat = .depth32Float
            descriptor.sampleCount = 1
            descriptor.usage = [.renderTarget, .shaderRead]
            // descriptor.storageMode = .memoryless
            return gpu.makeTexture(descriptor)
        }()
    }

    func changeViewportSize(_ size: CGSize) {
        scene.changeSize(size: size)
    }

    func update(drawTo metalLayer: CAMetalLayer, frameStatus: FrameStatus) {
        scene.update()

        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = offscreen
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.depthAttachment.texture = depthTexture
        descriptor.depthAttachment.loadAction = .clear
        descriptor.depthAttachment.clearDepth = 1.0
        descriptor.depthAttachment.storeAction = .dontCare
        gpu.counterSampler?.attachToRenderPass(descriptor: descriptor, name: "applicationRenderPass")
        let scenePassNodes = scene.makeFrameRenderPassNodes(descriptor: descriptor, pixelFormats: .init(colors: [Self.ColorPixelFormat], depth: .depth32Float))

        metalLayer.pixelFormat = Self.ColorPixelFormat
        guard let drawable = metalLayer.nextDrawable() else {
            appFatalError("drawable error.")
        }
        let presentPassNode = GpuPassNode(
            GpuRenderCommandDispatchPass(
                makeDescriptor: { d in
                    d.colorAttachments[0].texture = drawable.texture
                    d.colorAttachments[0].loadAction = .clear
                    d.colorAttachments[0].clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
                    d.colorAttachments[0].storeAction = .store
                    gpu.counterSampler?.attachToRenderPass(descriptor: d, name: "presentRenderPass")
                },
                dispatch: gpu.frame.buildFrameRenderCommand { builder in
                    builder.pixelFormats.colors[0] = Self.ColorPixelFormat
                    PassthroughtRenderer(renderCommandBuilder: builder).draw(offscreen)
                }
            ),
            dependencies: scenePassNodes.outputNodes
        )

        let pipeline = GpuPipeline()
        pipeline.registerNode([presentPassNode] + scenePassNodes.nodes)

        gpu.doCommand { commandBuffer in
            commandBuffer.addCompletedHandler { [self] _ in
                frameStatsReporter?.report(
                    frameStatus: frameStatus,
                    device: gpu.device,
                    gpuTime: commandBuffer.gpuTime()
                )
                gpu.counterSampler?.resolve(frame: frameStatus.frameCount)
            }

            pipeline.dispatch(to: commandBuffer)

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

        gpu.frame.next()
    }
}
