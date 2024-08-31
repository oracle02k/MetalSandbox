#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

namespace lifegame {

enum RenderTargetIndices {
    Color = 0
};

enum VertexBufferIndices {
    VertexBufferIndexGridParam = 0,
    VertexBufferIndexField = 1,
    VertexBufferIndexNewField = 2
};

struct GridParam{
    uint16_t width;
    uint16_t height;
};

struct VertexOut {
    simd_float4 position [[ position ]];
    simd_float4 color;
};

static uint xorshift32(const uint state) {
    uint value = state;
    value = value ^ (value << 13);
    value = value ^ (value >> 17);
    value = value ^ (value << 5);
    return value;
}

vertex VertexOut vertex_shader(
                               const device GridParam *grid_param [[ buffer(VertexBufferIndexGridParam) ]],
                               const device uint16_t *field [[ buffer(VertexBufferIndexField) ]],
                               uint vid [[ vertex_id  ]]
                               ) {
    float x = vid % grid_param->width;
    float y = vid / grid_param->width;
    
    VertexOut out;
    out.position = simd_float4(
                               x/(grid_param->width-1) * 2 - 1,
                               -(y/(grid_param->height-1) * 2 - 1),
                               1.0,
                               1.0
                               );
    out.color = simd_float4(0, field[vid], 0, 1);
    
    return out;
}

fragment simd_float4 fragment_shader(VertexOut vIn [[ stage_in ]]) {
    return vIn.color;
}

struct NeighborhoodPatternParam {
    int offset;
    int num;
};

kernel void update(
                   device const GridParam *grid_param [[ buffer(VertexBufferIndexGridParam) ]],
                   device const uint16_t* old_field [[ buffer(VertexBufferIndexField) ]],
                   device uint16_t* new_field [[ buffer(VertexBufferIndexNewField) ]],
                   uint index [[thread_position_in_grid]]
                   ) {
    const int gw = grid_param->width;
    const int pattern_buffer[] = {
        -gw-1, -gw, -gw+1, -1, +1, +gw-1, +gw, +gw+1,    //free case 0b00000000: 
        -gw, -gw+1, +1, +gw, +gw+1,                      //left case 0b00000001: 
        -1, +1, +gw-1, +gw, +gw+1,                       //top case 0b00000010: 
        +1, +gw, +gw+1,                                  //left top case 0b00000011: 
        -gw-1, -gw, -1, +gw-1, +gw,                      //right case 0b00000100: 
        -gw, +gw,                                        //left right case 0b00000101: 
        -1, +gw-1, +gw,                                  //right top case 0b00000110: 
        +gw,                                             //left right top case 0b00000111: 
        -gw-1, -gw, -gw+1, -1, +1,                       //bottom case 0b00001000:
        -gw, -gw+1, +1,                                  //left bottom case 0b00001001: 
        -1, +1,                                          //top bottom case 0b00001010: 
        +1,                                              //left top bottom case 0b00001011: 
        -gw-1, -gw, -1,                                  //right bottom case 0b00001100: 
        -gw,                                             //left right bottom case 0b00001101: 
        -1,                                              //right top bottom case 0b00001110: 
        //left right top bottom case 0b00001111:
    };
    
    const NeighborhoodPatternParam pattern_params[] = {
        {0, 8},
        {8, 5},
        {13, 5},
        {18, 3},
        {21, 5},
        {26, 2},
        {28, 3},
        {31, 1},
        {32, 5},
        {37, 3},
        {40, 2},
        {42, 1},
        {43, 3},
        {46, 1},
        {47, 1},
        {48, 0}
    };
    
    const int x = index % grid_param->width;
    const int y = index / grid_param->width;
    
    int flags = 0;
    flags |= (x == 0) << 0;
    flags |= (y == 0) << 1;
    flags |= (x == grid_param->width -1) << 2;
    flags |= (y == grid_param->height -1) << 3;
    
    // 近傍状態取得
    auto param = pattern_params[flags];
    int neighborhood_status = 0;
    for(int i = 0; i < param.num; i++){
        auto offset = pattern_buffer[param.offset + i];
        neighborhood_status += old_field[index+offset];
    }
    
    neighborhood_status = neighborhood_status <= 4 ? neighborhood_status : 4;
    
    int next[] = {0,0,old_field[index],1,0};
    new_field[index] = next[neighborhood_status];
}

kernel void reset(
  device uint16_t* new_field [[ buffer(VertexBufferIndexNewField) ]],
  uint index [[thread_position_in_grid]]
) {
    // シェーダ内からの呼び出し
    threadgroup uint rnd = 2463534242;
    rnd = xorshift32(rotate(rnd, index));
    
    float value = rnd % 2; // 0 or 1
    new_field[index] = value;
}
}
