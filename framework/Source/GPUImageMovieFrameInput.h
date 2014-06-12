//
//  GPUImageMovieFrameInput.h
//  GPUImage
//
//  Created by Eric Yang on 6/12/14.
//  Copyright (c) 2014 Brad Larson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GPUImageContext.h"

@interface GPUImageMovieFrameInput : NSObject<GPUImageInput>

- (void)setPixelBuffer:(CVPixelBufferRef)buffer;

@end
