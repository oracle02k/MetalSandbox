#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

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
    simd_float2 texCoord;
};

struct VertexOut {
    simd_float4 position [[ position ]];
    simd_float4 color;
    simd_float2 texCoord;
};

vertex VertexOut simple2d_vertex_function(
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

fragment simd_float4 simple2d_fragment_function(VertexOut vIn [[ stage_in ]]) {
    return vIn.color;
}

fragment simd_float4 red_fragment_function(VertexOut vIn [[ stage_in ]]) {
    return simd_float4(1,0,0,1);
}

vertex VertexOut texcoord_vertex_function(
    const device VertexIn *vertices [[ buffer(0) ]],
    uint vertexID [[ vertex_id  ]]
) {
    VertexOut vOut;
    vOut.position = simd_float4(vertices[vertexID].position,1);
    vOut.color = vertices[vertexID].color;
    vOut.texCoord = vertices[vertexID].texCoord;

    return vOut;
}

fragment simd_float4 texcoord_fragment_function(
    VertexOut vIn [[ stage_in ]],
    texture2d<float> colorTexture [[texture(0)]]
) {
    constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);
    simd_float4 color = colorTexture.sample(colorSampler, vIn.texCoord);
    return simd_float4(color.rgb, 1.0);
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

namespace IndirectRenderer {
// Vertex shader outputs and per-fragment inputs
struct RasterizerData
{
    float4 position [[position]];
    float2 tex_coord;
};

struct Vertex {
    packed_float2 position;
    packed_float2 texcoord;
};

// Structure defining the layout of variable changing once (or less) per frame
struct FrameState {
    simd_float2 aspectScale;
};

// Structure defining parameters for each rendered object
struct ObjectPerameters {
    packed_float2 position;
};

// Buffer index values shared between the vertex shader and C code
enum VertexBufferIndex {
    VertexBufferIndexVertices = 0,
    VertexBufferIndexObjectParams,
    VertexBufferIndexFrameState,
};

// Buffer index values shared between the compute kernel and C code
enum KernelBufferIndex {
    KernelBufferIndexFrameState = 0,
    KernelBufferIndexObjectParams,
    KernelBufferIndexArguments,
};

enum ArgumentBufferBufferID {
    ArgumentBufferBufferIDCommandBuffer = 0,
    ArgumentBufferBufferIDObjectMesh,
};

vertex RasterizerData vertexShader(
                                   uint                         vertexID      [[ vertex_id ]],
                                   uint                         objectIndex   [[ instance_id ]],
                                   const device Vertex *    vertices      [[ buffer(VertexBufferIndexVertices) ]],
                                   const device ObjectPerameters* object_params [[ buffer(VertexBufferIndexObjectParams) ]],
                                   constant FrameState *    frame_state   [[ buffer(VertexBufferIndexFrameState) ]]
                                   ) {
    const float ViewScale = 0.05;    // Scale of each object when drawn
    RasterizerData out;
    
    float2 worldObjectPostion  = object_params[objectIndex].position;
    float2 modelVertexPosition = vertices[vertexID].position;
    float2 worldVertexPosition = modelVertexPosition + worldObjectPostion;
    float2 clipVertexPosition  = frame_state->aspectScale * ViewScale * worldVertexPosition;
    
    out.position = float4(clipVertexPosition.x, clipVertexPosition.y, 0, 1);
    out.tex_coord = float2(vertices[vertexID].texcoord);
    
    return out;
}

vertex RasterizerData vertexShader2(
   uint                     vertexID      [[ vertex_id ]],
   const device Vertex *    vertices      [[ buffer(VertexBufferIndexVertices) ]],
   const device ObjectPerameters* object_params [[ buffer(VertexBufferIndexObjectParams) ]],
   constant FrameState *    frame_state   [[ buffer(VertexBufferIndexFrameState) ]]
) {
    const float ViewScale = 0.1;    // Scale of each object when drawn
    RasterizerData out;
    
    float2 worldObjectPostion  = object_params->position;
    float2 modelVertexPosition = vertices[vertexID].position;
    float2 worldVertexPosition = modelVertexPosition + worldObjectPostion;
    float2 clipVertexPosition  = frame_state->aspectScale * ViewScale * worldVertexPosition;
    
    out.position = float4(clipVertexPosition.x, clipVertexPosition.y, 0, 1);
    out.tex_coord = float2(vertices[vertexID].texcoord);
    
    return out;
}

fragment float4 fragmentShader(RasterizerData in [[ stage_in ]])
{
    float4 output_color = float4(in.tex_coord.x, in.tex_coord.y, 0, 1);
    
    return output_color;
}
}
