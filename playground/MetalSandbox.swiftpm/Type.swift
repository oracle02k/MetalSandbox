import simd

enum VertexInputIndex: Int {
    case Vertices1
    case Vertices2
    case Vertices3
    case Vertices4
    case Viewport
}

struct Viewport {
    let leftTop: simd_float2
    let rightBottom: simd_float2
}
