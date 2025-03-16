import Metal
import simd

class PassthroughtTextureRenderable{
    lazy var positions: TypedBuffer<simd_float3> = uninitialized()
    lazy var texCoords: TypedBuffer<simd_float2> = uninitialized()
    lazy var source: MTLTexture = uninitialized()
    
    func build(gpu: GpuContext){
        positions = gpu.makeTypedBuffer(elementCount: 6, options: []) as TypedBuffer<simd_float3>
        positions[0] = .init(-1, 1, 0.0)
        positions[1] = .init(-1, -1, 0.0)
        positions[2] = .init(1, 1, 0.0)
        positions[3] = .init(1, 1, 0.0)
        positions[4] = .init(-1, -1, 0.0)
        positions[5] = .init(1, -1, 0.0)
        
        texCoords = gpu.makeTypedBuffer(elementCount: 6, options: []) as TypedBuffer<simd_float2>
        texCoords[0] = .init(0, 1)
        texCoords[1] = .init(0, 0)
        texCoords[2] = .init(1, 1)
        texCoords[3] = .init(1, 1)
        texCoords[4] = .init(0, 0)
        texCoords[5] = .init(1, 0)
    }
    
    func bindSource(_ source:MTLTexture){
        self.source = source
    }
}
