//
//  Shaders.metal
//  OrlyLiquidMetal
//
//  Created by Orlando Gordillo on 5/15/17.
//  Copyright © 2017 Orlando Gordillo. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
};

struct Uniforms {
    float4x4 ndcMatrix;
    float ptmRatio;
    float pointSize;
};

vertex VertexOut particle_vertex(const device packed_float2* vertex_array [[buffer(0)]],
                                 const device Uniforms& uniforms [[buffer(1)]],
                                 unsigned int vid [[vertex_id]]) {
    VertexOut vertexOut;
    float2 position = vertex_array[vid];
    vertexOut.position =
    uniforms.ndcMatrix * float4(position.x * uniforms.ptmRatio, position.y * uniforms.ptmRatio, 0, 1);
    vertexOut.pointSize = uniforms.pointSize;
    
    
    vertexOut.position = uniforms.ndcMatrix * float4(position.x * uniforms.ptmRatio, position.y * uniforms.ptmRatio, 0, 1);
    
    return vertexOut;
    
}

fragment half4 basic_yellow_fragment() {
   
    
   
    return half4(1.0, 1.0, 0.0, 1.0);
}

fragment half4 basic_green_fragment() {
    
    
    
    return half4(0.0, 1.0, 0.0, 1.0);
}

fragment half4 basic_blue_fragment() {
    
    
    
    return half4(0.0, 0.0, 1.0, 1.0);
}

fragment half4 basic_red_fragment() {
    
    
    
    return half4(1.0, 0.0, 0.0, 1.0);
}

fragment half4 basic_white_fragment() {
    
    
    
    return half4(1.0, 1.0, 1.0, 1.0);
}

fragment half4 basic_pink_fragment() {
    
    
    
    return half4(0.95, 0.56, 0.9, 1.0);
}

fragment half4 basic_orange_fragment() {
    
    
    
    return half4(0.95, 0.56, 0.0, 1.0);
}

fragment half4 basic_skyblue_fragment() {
    
    
    
    return half4(0.5, 0.9, 0.95, 1.0);
}

fragment half4 basic_purple_fragment() {
    
    
    
    return half4(0.5, 0.9, 0.95, 1.0);
}
