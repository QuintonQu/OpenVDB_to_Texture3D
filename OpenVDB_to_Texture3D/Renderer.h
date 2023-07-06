//
//  Render.h
//  OpenVDB_to_Texture3D
//
//  Created by Ziyuan Qu on 2023/7/6.
//

#ifndef Renderer_h
#define Renderer_h

#import <MetalKit/MetalKit.h>

@interface Renderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView;

@end

#endif /* Render_h */
