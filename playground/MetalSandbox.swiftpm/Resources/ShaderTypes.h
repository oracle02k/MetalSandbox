#ifndef ShaderTypes_h
#define ShaderTypes_h
#include <simd/simd.h>

typedef enum VertexInputIndex {
    VertexInputIndexVertices1    = 0,
    VertexInputIndexVertices2,
    VertexInputIndexVertices3,
    VertexInputIndexVertices4,
    VertexInputIndexViewport,
} VertexInputIndex;

typedef struct {
    vector_float2 leftTop;
    vector_float2 rightBottom;
} Viewport;

#endif
