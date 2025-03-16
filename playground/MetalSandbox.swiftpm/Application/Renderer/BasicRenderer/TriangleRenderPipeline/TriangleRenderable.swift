import Metal
import simd

class TriangleRenderable {
    private(set) var triangleCount = 0
    private(set) lazy var positions: TypedBuffer<simd_float3> = uninitialized()
    private(set) lazy var colors: TypedBuffer<simd_float4> = uninitialized()

    func build(gpu: GpuContext, triangleCount: Int) {
        self.triangleCount = triangleCount
        positions = gpu.makeTypedBuffer(type: simd_float3.self, elementCount: 3 * triangleCount, options: [])
        colors = gpu.makeTypedBuffer(type: simd_float4.self, elementCount: 3 * triangleCount, options: [])

        for i in 0..<triangleCount {
            positions[0 + i * 3] = .init(160, 0, 0.0)
            positions[1 + i * 3] = .init(0, 320, 0.0)
            positions[2 + i * 3] = .init(320, 320, 0.0)
            colors[0 + i * 3] = .init(1, 0, 0, 1)
            colors[1 + i * 3] = .init(0, 1, 0, 1)
            colors[2 + i * 3] = .init(0, 0, 1, 1)
        }
    }
}
