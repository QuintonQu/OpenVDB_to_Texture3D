//
//  Render.m
//  OpenVDB_to_Texture3D
//
//  Created by Ziyuan Qu on 2023/7/6.
//

#import "Renderer.h"
#import <simd/simd.h>
#import <MetalKit/MetalKit.h>
#import "ShaderType.h"
#include <stdint.h>

#include <openvdb/openvdb.h>
#include <openvdb/tools/Interpolation.h>
#include <openvdb/tools/ValueTransformer.h>
#import <Foundation/Foundation.h>

#include <iostream>

// Main class performing the rendering
@implementation Renderer
{
    id<MTLDevice> _device;

    // The render pipeline generated from the vertex and fragment shaders in the .metal shader file.
    id<MTLRenderPipelineState> _pipelineState;

    // The command queue used to pass commands to the device.
    id<MTLCommandQueue> _commandQueue;

    // The current size of the view, used as an input to the vertex shader.
    vector_uint2 _viewportSize;
    
    id<MTLTexture> _volumeTex;
    
    unsigned int _frameIndex;
}

uint16_t floatToHalf(float value)
{
    uint32_t bits = *(uint32_t *)&value;
    uint32_t sign = (bits >> 31) & 0x1;
    int32_t exponent = ((bits >> 23) & 0xFF) - 127;
    uint32_t mantissa = bits & 0x7FFFFF;

    if(exponent == 128)
    {
        // NaN or Infinity
        exponent = 16;
        mantissa >>= 13;
    }
    else if(exponent > 15)
    {
        // Overflow
        return sign << 15 | 0x7C00;
    }
    else if(exponent > -15)
    {
        // Normalized number
        exponent += 15;
        mantissa >>= 13;
    }
    else if(exponent > -25)
    {
        // Subnormal number
        mantissa |= 0x800000;
        mantissa >>= -14 - exponent;
        exponent = -15 + 1;
    }
    else
    {
        // Underflow
        return sign << 15;
    }

    return sign << 15 | exponent << 10 | mantissa;
}

id<MTLTexture> createVolume(id<MTLDevice> device){
    openvdb::initialize();
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"bunny_cloud" ofType:@"vdb"];
    openvdb::io::File file([path UTF8String]);
//    openvdb::io::File file("/Users/quinton/Documents/OpenVDB_to_Texture3D/model/bunny_cloud.vdb");
    file.open();
    
    openvdb::GridBase::Ptr base_grid;
    std::string gridname = "";
    
    for (openvdb::io::File::NameIterator name_iter = file.beginName();
        name_iter != file.endName(); ++name_iter)
    {
        // Read in only the grid we are interested in.
        if (gridname == "" || name_iter.gridName() == gridname) {
            std::cout << "reading grid " << name_iter.gridName() << std::endl;
            base_grid = file.readGrid(name_iter.gridName());
            if (gridname == "")
                break;
        } else {
            std::cout << "skipping grid " << name_iter.gridName() << std::endl;
        }
    }
    std::cout << "vdb file reading done!" << std::endl;
    
    file.close();
    openvdb::FloatGrid::Ptr grid = openvdb::gridPtrCast<openvdb::FloatGrid>(base_grid);
    auto bbox = grid->evalActiveVoxelBoundingBox();
    openvdb::FloatGrid::Accessor accessor = grid->getAccessor();

    int width = bbox.max().x() - bbox.min().x();
    int height = bbox.max().y() - bbox.min().y();
    int depth = bbox.max().z() - bbox.min().z();

    uint16_t* values = (uint16_t*)malloc(sizeof(uint16_t) * width * height * depth * 4);
    int value_index = 0;
    for (int k = bbox.min().z(); k < bbox.max().z(); ++k) {
        for (int j = bbox.min().y(); j < bbox.max().y(); ++j) {
            for (int i = bbox.min().x(); i < bbox.max().x(); ++i) {
                values[value_index] = (uint16_t) 0.0f;
                values[value_index + 1] = (uint16_t) 0.0f;
                values[value_index + 2] = (uint16_t) 0.0f;
                values[value_index + 3] = floatToHalf(accessor.getValue(openvdb::Coord(i, j, k)));
//                values[value_index + 3] = accessor.getValue(openvdb::Coord(i, j, k));
                value_index += 4;
            }
        }
    }
    std::cout << "vdb data extraction done!" << std::endl;
    
    MTLTextureDescriptor* textureDescriptor = [MTLTextureDescriptor new];
    textureDescriptor.pixelFormat = MTLPixelFormatRGBA16Float;
    textureDescriptor.textureType = MTLTextureType3D;
    textureDescriptor.width = width;
    textureDescriptor.height = height;
    textureDescriptor.depth = depth;
    
    id<MTLTexture> texture = [device newTextureWithDescriptor:textureDescriptor];
    [texture replaceRegion:MTLRegionMake3D(0, 0, 0, width, height, depth)
               mipmapLevel:	0
                     slice: 0
                 withBytes:values
               bytesPerRow:sizeof(uint16_t) * width * 4
             bytesPerImage:sizeof(uint16_t) * width * height * 4];
    
    free(values);
    return texture;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView
{
    self = [super init];
    if(self)
    {
        NSError *error;

        _device = mtkView.device;

        // Load all the shader files with a .metal file extension in the project.
        id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

        id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
        id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];

        // Configure a pipeline descriptor that is used to create a pipeline state.
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Simple Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;

        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                 error:&error];
                
        // Pipeline State creation could fail if the pipeline descriptor isn't set up properly.
        //  If the Metal API validation is enabled, you can find out more information about what
        //  went wrong.  (Metal API validation is enabled by default when a debug build is run
        //  from Xcode.)
        NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error);

        // Create the command queue
        _commandQueue = [_device newCommandQueue];
        
        //Create a volume
        _volumeTex = createVolume(_device);
    }

    return self;
}

/// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    // Save the size of the drawable to pass to the vertex shader.
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
}

/// Called whenever the view needs to render a frame.
- (void)drawInMTKView:(nonnull MTKView *)view
{
//    static const AAPLVertex triangleVertices[] =
//    {
//        // 2D positions,    RGBA colors
//        { {  250,  -250 }, { 1, 0, 0, 1 } },
//        { { -250,  -250 }, { 0, 1, 0, 1 } },
//        { {    0,   250 }, { 0, 0, 1, 1 } },
//    };

    // Create a new command buffer for each render pass to the current drawable.
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    // Obtain a renderPassDescriptor generated from the view's drawable textures.
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    if(renderPassDescriptor != nil)
    {
        // Create a render command encoder.
        id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        // Set the region of the drawable to draw into.
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, static_cast<double>(_viewportSize.x), static_cast<double>(_viewportSize.y), 0.0, 1.0 }];
        
        [renderEncoder setRenderPipelineState:_pipelineState];
        
        // Pass the volume texture
        [renderEncoder setFragmentTexture:_volumeTex atIndex:0];

//        // Pass in the parameter data.
//        [renderEncoder setVertexBytes:triangleVertices
//                               length:sizeof(triangleVertices)
//                              atIndex:AAPLVertexInputIndexVertices];
//        
//        [renderEncoder setVertexBytes:&_viewportSize
//                               length:sizeof(_viewportSize)
//                              atIndex:AAPLVertexInputIndexViewportSize];
        
        [renderEncoder setVertexBytes:&_frameIndex length:sizeof(unsigned int) atIndex:3];
        
        _frameIndex++;

        // Draw the triangle.
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:6];

        [renderEncoder endEncoding];

        // Schedule a present once the framebuffer is complete using the current drawable.
        [commandBuffer presentDrawable:view.currentDrawable];
    }

    // Finalize rendering here & push the command buffer to the GPU.
    [commandBuffer commit];
}

@end

