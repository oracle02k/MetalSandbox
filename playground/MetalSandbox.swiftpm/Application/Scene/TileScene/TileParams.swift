import simd

struct TileActorParams {
    var modelMatrix: matrix_float4x4
    var color: vector_float4
}

struct TileCameraParams {
    var cameraPos: vector_float3
    var viewProjectionMatrix: matrix_float4x4
}
