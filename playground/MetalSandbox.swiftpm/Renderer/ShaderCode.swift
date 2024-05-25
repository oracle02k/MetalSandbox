let shader = """
#include <metal_stdlib>
using namespace metal;
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

vertex VertexOut basic_vertex_function(
    const device VertexIn *vertices [[ buffer(0) ]],
    uint vertexID [[ vertex_id  ]]
) {
    VertexOut vOut;
    vOut.position = float4(vertices[vertexID].position,1);
    vOut.color = vertices[vertexID].color;

    return vOut;
}

fragment float4 basic_fragment_function(VertexOut vIn [[ stage_in ]]) {
    return vIn.color;
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
"""
