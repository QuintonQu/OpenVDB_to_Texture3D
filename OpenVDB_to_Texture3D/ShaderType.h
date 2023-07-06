//
//  ShaderType.h
//  OpenVDB_to_Texture3D
//
//  Created by Ziyuan Qu on 2023/7/6.
//

#ifndef ShaderType_h
#define ShaderType_h

#include <simd/simd.h>

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs
// match Metal API buffer set calls.
typedef enum AAPLVertexInputIndex
{
    AAPLVertexInputIndexVertices     = 0,
    AAPLVertexInputIndexViewportSize = 1,
} AAPLVertexInputIndex;

//  This structure defines the layout of vertices sent to the vertex
//  shader. This header is shared between the .metal shader and C code, to guarantee that
//  the layout of the vertex array in the C code matches the layout that the .metal
//  vertex shader expects.
typedef struct
{
    vector_float2 position;
    vector_float4 color;
} AAPLVertex;


#endif /* ShaderType_h */
