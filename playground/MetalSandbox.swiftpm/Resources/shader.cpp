#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

typedef enum VertexInputIndex {
    VertexInputIndexVertices1    = 0,
    VertexInputIndexVertices2,
    VertexInputIndexVertices3,
    VertexInputIndexVertices4,
    VertexInputIndexViewport,
} VertexInputIndex;

struct Viewport {
    vector_float2 leftTop;
    vector_float2 rightBottom;
};

struct VertexIn {
    float3 position;
    float4 color;
    float2 texCoord;
};

struct VertexOut {
    float4 position [[ position ]];
    float4 color;
    float2 texCoord;
};

vertex VertexOut simple2d_vertex_function(
    const device VertexIn *vertices [[ buffer(VertexInputIndexVertices1) ]],
    const device Viewport *viewport [[ buffer(VertexInputIndexViewport) ]],
    uint vertexID [[ vertex_id  ]]
) {
    vector_float2 viewportSize = viewport->rightBottom - viewport->leftTop;
    
    vector_float2 pixelSpacePos = vertices[vertexID].position.xy;
    vector_float2 position = 2 * (pixelSpacePos - viewport->leftTop)/viewportSize - 1.0; // 2(x - sx)/w - 1.0
    position.y *= - 1;
    
    VertexOut vOut;
    vOut.position = float4(position, vertices[vertexID].position.z,1);
    vOut.color = vertices[vertexID].color;

    return vOut;
}

fragment float4 simple2d_fragment_function(VertexOut vIn [[ stage_in ]]) {
    return vIn.color;
}

fragment float4 red_fragment_function(VertexOut vIn [[ stage_in ]]) {
    return float4(1,0,0,1);
}

vertex VertexOut texcoord_vertex_function(
    const device VertexIn *vertices [[ buffer(0) ]],
    uint vertexID [[ vertex_id  ]]
) {
    VertexOut vOut;
    vOut.position = float4(vertices[vertexID].position,1);
    vOut.color = vertices[vertexID].color;
    vOut.texCoord = vertices[vertexID].texCoord;

    return vOut;
}

fragment float4 texcoord_fragment_function(
    VertexOut vIn [[ stage_in ]],
    texture2d<float> colorTexture [[texture(0)]]
) {
    constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);
    float4 color = colorTexture.sample(colorSampler, vIn.texCoord);
    return float4(color.rgb, 1.0);
}

 kernel void add_arrays_compute_function(
    device const float* inA,
    device const float* inB,
    device float* result,
    uint index [[thread_position_in_grid]]
) {
    // the for-loop is replaced with a collection of threads, each of which
    // calls this function.
    result[index] = inA[index] + inB[index];
}
