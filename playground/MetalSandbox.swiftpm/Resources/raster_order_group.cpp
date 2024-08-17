#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

namespace raster_order_group {

struct VertexIn {
    simd_float3 position;
    simd_float4 color;
    simd_float2 texCoord;
};

struct VertexOut {
    simd_float4 position [[ position ]];
    simd_float4 pos;
    simd_float4 color;
    simd_float2 texCoord;
};

vertex VertexOut texcoord_vertex_shader(
  const device VertexIn *vertices [[ buffer(0) ]],
  uint vertexID [[ vertex_id  ]]
) {
    VertexOut vOut;
    vOut.position = simd_float4(vertices[vertexID].position,1);
    vOut.pos = vOut.position;
    vOut.color = vertices[vertexID].color;
    vOut.texCoord = vertices[vertexID].texCoord;
    
    return vOut;
}

fragment simd_float4 rog_0_fragment(
    VertexOut vIn [[ stage_in ]],
    texture2d<float> colorTexture [[texture(0)]],
    texture2d<float, metal::access::write> writeTexture [[texture(1), raster_order_group(0)]]
) {
    constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);
    simd_float4 color = colorTexture.sample(colorSampler, vIn.texCoord);
    color = simd_float4(color.rgb,  vIn.color.w);
    
    float vx = (vIn.pos.x + 1.0)/2.f;
    float vy = 1.f - (vIn.pos.y + 1.0)/2.f;
    uint2 coord = uint2(vx * 760, vy * 760);
    
    float4 color2 = float4(vx,vy,0,1);
    writeTexture.write(color, coord);
    
    return color;
}

fragment simd_float4 rog_1_fragment(
  VertexOut vIn [[ stage_in ]],
  texture2d<float> colorTexture [[texture(0)]],
  texture2d<float, metal::access::write> writeTexture [[texture(1), raster_order_group(1)]]
) {
    constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);
    simd_float4 color = colorTexture.sample(colorSampler, vIn.texCoord);
    color = simd_float4(color.rgb,  vIn.color.w);
    
    float vx = (vIn.pos.x + 1.0)/2.f;
    float vy = 1.f - (vIn.pos.y + 1.0)/2.f;
    uint2 coord = uint2(vx * 760, vy * 760);
    
    float4 color2 = float4(vx,vy,0,1);
    writeTexture.write(color, coord);
    
    return color;
}
}
