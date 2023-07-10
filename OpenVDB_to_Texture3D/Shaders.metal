//
//  Shaders.metal
//  OpenVDB_to_Texture3D
//
//  Created by Ziyuan Qu on 2023/7/6.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderType.h"

// Vertex shader outputs and fragment shader inputs
struct RasterizerData
{
    // The [[position]] attribute of this member indicates that this value
    // is the clip space position of the vertex when this structure is
    // returned from the vertex function.
    float4 position [[position]];

    // Since this member does not have a special attribute, the rasterizer
    // interpolates its value with the values of the other triangle vertices
    // and then passes the interpolated value to the fragment shader for each
    // fragment in the triangle.
    float4 color;
    
    float3 uv;
};

constant float2 quadVertices[] = {
    float2(-1, -1),
    float2(-1,  1),
    float2( 1,  1),
    float2(-1, -1),
    float2( 1,  1),
    float2( 1, -1)
};

vertex RasterizerData
vertexShader(uint vertexID [[vertex_id]],
//             constant AAPLVertex *vertices [[buffer(AAPLVertexInputIndexVertices)]],
//             constant vector_uint2 *viewportSizePointer [[buffer(AAPLVertexInputIndexViewportSize)]],
             constant unsigned int &frame_index [[buffer(3)]])
{
//    RasterizerData out;
//
//    // Index into the array of positions to get the current vertex.
//    // The positions are specified in pixel dimensions (i.e. a value of 100
//    // is 100 pixels from the origin).
//    float2 pixelSpacePosition = vertices[vertexID].position.xy;
//
//    // Get the viewport size and cast to float.
//    vector_float2 viewportSize = vector_float2(*viewportSizePointer);
//    
//
//    // To convert from positions in pixel space to positions in clip-space,
//    //  divide the pixel coordinates by half the size of the viewport.
//    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
//    out.position.xy = pixelSpacePosition / (viewportSize / 2.0);
//
//    // Pass the input color directly to the rasterizer.
//    out.color = vertices[vertexID].color;
    
    float2 position = quadVertices[vertexID];
    
    RasterizerData out;
    
    out.position = float4(position, 0, 1);
    out.uv = float3(position * 0.5f + 0.5f, float(frame_index % 437) / 437.f);

    return out;
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               texture3d<half> volume_texture [[texture(0)]])
{
    // Return the interpolated color.
//    constexpr sampler linearFilterSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    constexpr sampler sam(min_filter::nearest, mag_filter::nearest, mip_filter::none);
    half density = volume_texture.sample(sam, in.uv).a;
    density *= 5;
    return float4(density, 0.7 * density, density, 1.0f);
//    return float4(1.0, 0.0, 0.0, 1.0);
}
