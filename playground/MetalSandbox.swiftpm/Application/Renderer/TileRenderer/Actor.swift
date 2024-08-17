import MetalKit

class Actor {
    let color: vector_float4
    let position: vector_float3
    let rotation: vector_float3
    let scale: vector_float3

    init(color: vector_float4, position: vector_float3, rotation: vector_float3, scale: vector_float3) {
        self.color = color
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }
}
