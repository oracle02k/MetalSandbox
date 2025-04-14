import simd

struct TileActorParams {
    var modelMatrix: matrix_float4x4
    var color: vector_float4
}

struct TileCameraParams{
    var cameraPos: vector_float3
    var viewProjectionMatrix: matrix_float4x4
    
    init(cameraPos: vector_float3, viewProjectionMatrix: matrix_float4x4) {
        self.cameraPos = cameraPos
        self.viewProjectionMatrix = viewProjectionMatrix
    }
}
