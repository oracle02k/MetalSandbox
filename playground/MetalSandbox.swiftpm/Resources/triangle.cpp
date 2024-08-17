#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

namespace triangle {

enum VertexInputIndex {
    VertexInputIndexVertices1    = 0,
    VertexInputIndexVertices2,
    VertexInputIndexVertices3,
    VertexInputIndexVertices4,
    VertexInputIndexViewport,
};

struct Viewport {
    simd_float2 leftTop;
    simd_float2 rightBottom;
};

struct VertexIn {
    simd_float3 position;
    simd_float4 color;
};

struct VertexOut {
    simd_float4 position [[ position ]];
    simd_float4 color;
};

vertex VertexOut vertex_shader(
  const device VertexIn *vertices [[ buffer(VertexInputIndexVertices1) ]],
  const device Viewport *viewport [[ buffer(VertexInputIndexViewport) ]],
  uint vertexID [[ vertex_id  ]]
) {
    simd_float2 viewportSize = viewport->rightBottom - viewport->leftTop;
    
    simd_float2 pixelSpacePos = vertices[vertexID].position.xy;
    simd_float2 position = 2 * (pixelSpacePos - viewport->leftTop)/viewportSize - 1.0; // 2(x - sx)/w - 1.0
    position.y *= - 1;
    
    VertexOut vOut;
    vOut.position = float4(position, vertices[vertexID].position.z,1);
    vOut.color = vertices[vertexID].color;
    
    return vOut;
}

fragment simd_float4 fragment_shader(VertexOut vIn [[ stage_in ]]) {
    return vIn.color;
}

}
