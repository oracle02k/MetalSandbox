#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

namespace indirect {
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

vertex RasterizerData vertex_shader_with_instance(
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

vertex RasterizerData vertex_shader(
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

fragment float4 fragment_shader(RasterizerData in [[ stage_in ]])
{
    float4 output_color = float4(in.tex_coord.x, in.tex_coord.y, 0, 1);
    
    return output_color;
}
}

