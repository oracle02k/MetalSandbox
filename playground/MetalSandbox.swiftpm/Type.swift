typealias int2 = SIMD2<Int32>
typealias int3 = SIMD3<Int32>
typealias int4 = SIMD4<Int32>

typealias float2 = SIMD2<Float>
typealias float3 = SIMD3<Float>
typealias float4 = SIMD4<Float>

enum VertexInputIndex: Int {
    case Vertices1
    case Vertices2
    case Vertices3
    case Vertices4
    case Viewport
}

struct Viewport {
    let leftTop: float2
    let rightBottom: float2
}
