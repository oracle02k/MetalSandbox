import simd
import Foundation

class TileScene{
    let ActorCountPerColumn = 4
    let TransparentColumnCount = 4
    let renderer = TileRenderer()
    private var opaqueActors = [TileActor]()
    private var transparentActors = [TileActor]()
    private var projectionMatrix = matrix_float4x4()
    
    func build() {
        var genericColors: [vector_float4] = [
            .init(0.3, 0.9, 0.1, 1.0),
            .init(0.05, 0.5, 0.4, 1.0),
            .init(0.5, 0.05, 0.9, 1.0),
            .init(0.9, 0.1, 0.1, 1.0)
        ]
        
        var startPosition = vector_float3(7.0, 0.1, 12.0)
        let standardScale = vector_float3(1.5, 1.0, 1.5)
        let standardRotation = vector_float3(90.0, 0.0, 0.0)
        
        // Create opaque rotating quad actors at the rear of each column.
        for _ in 0..<ActorCountPerColumn {
            let actor = TileActor(
                color: .init(0.5, 0.4, 0.3, 1.0),
                position: startPosition,
                rotation: standardRotation,
                scale: standardScale
            )
            
            opaqueActors.append(actor)
            startPosition[0] -= 4.5
        }
        
        // Create an opaque floor actor.
        do {
            let color = vector_float4(0.7, 0.7, 0.7, 1.0)
            let actor = TileActor(color: color,
                                  position: .init(0.0, -2.0, 6.0),
                                  rotation: .init(0.0, 0.0, 0.0),
                                  scale: .init(8.0, 1.0, 9.0))
            actor.enableRotation = false
            opaqueActors.append(actor)
        }
        
        startPosition = .init(7.0, 0.1, 0.0)
        var curPosition = startPosition
        
        // Create the transparent actors.
        for _ in 0..<TransparentColumnCount {
            for rowIndex in 0..<ActorCountPerColumn {
                genericColors[rowIndex][3] -= 0.2
                let actor = TileActor(color: genericColors[rowIndex],
                                      position: curPosition,
                                      rotation: standardRotation,
                                      scale: standardScale)
                transparentActors.append(actor)
                curPosition[2] += 3.0
            }
            startPosition[0] -= 4.5
            curPosition = startPosition
        }
    }
    
    func changeSize(size: CGSize) {
        let aspect = Float(size.width / size.height)
        projectionMatrix = matrix_perspective_left_hand(radians_from_degrees(65.0), aspect, 1.0, 150.0)
    }
    
    func makeCameraParams() -> TileCameraParams{
        let eyePos = vector_float3(0.0, 2.0, -12.0)
        let eyeTarget = vector_float3(eyePos.x, eyePos.y - 0.25, eyePos.z + 1.0)
        let eyeUp = vector_float3(0.0, 1.0, 0.0)
        let viewMatrix = matrix_look_at_left_hand(eyePos, eyeTarget, eyeUp)
        
        return TileCameraParams(
            cameraPos: eyePos,
            viewProjectionMatrix: matrix_multiply(projectionMatrix, viewMatrix)
        )
    }
    
    func update(){
        for actor in opaqueActors{
            actor.update()
        }
        
        for actor in transparentActors{
            actor.update()
        }
    }
    
    func draw(_ renderCommandBuilder: RenderCommandBuilder) {
        let opaqueActorParams = opaqueActors.map{ $0.toActorParams()}
        let transparentActors = transparentActors.map{ $0.toActorParams()}
        let cameraParams = makeCameraParams()
        
        renderer.draw(
            renderCommandBuilder,
            opaqueActorParams: opaqueActorParams, 
            transparentActorParams: transparentActors,
            cameraParams: cameraParams
        )
    }
}
