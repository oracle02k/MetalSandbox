import simd

class TileActor {
    private(set) var color: vector_float4
    private(set) var position: vector_float3
    private(set) var rotation: vector_float3
    private(set) var scale: vector_float3
    var enableRotation = true

    init(color: vector_float4, position: vector_float3, rotation: vector_float3, scale: vector_float3) {
        self.color = color
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }

    func update() {
        if enableRotation {
            rotation.z += 0.5
        }
    }

    func toActorParams() -> TileActorParams {
        let translationMatrix = matrix4x4_translation(position)
        let scaleMatrix = matrix4x4_scale(scale)
        let rotationMatrixX = matrix4x4_rotation(radians_from_degrees(rotation.x), 1.0, 0.0, 0.0)
        let rotationMatrixZ = matrix4x4_rotation(radians_from_degrees(rotation.z), 0.0, 0.0, 1.0)
        let rotationMatrix = matrix_multiply(rotationMatrixX, rotationMatrixZ)

        return TileActorParams(
            modelMatrix: matrix_multiply(translationMatrix, matrix_multiply(rotationMatrix, scaleMatrix)),
            color: color
        )
    }
}
