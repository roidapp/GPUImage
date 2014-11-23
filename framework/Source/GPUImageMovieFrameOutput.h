//
//  GPUImageMovieFrameOutput.h
//  GPUImage
//
//  Created by Eric Yang on 6/12/14.
//  Copyright (c) 2014 Brad Larson. All rights reserved.
//

#import "GPUImageOutput.h"

@interface GPUImageMovieFrameOutput : GPUImageOutput
- (void)processPixelBuffer:(CVPixelBufferRef)movieFrame withSampleTime:(CMTime)currentSampleTime;
@end
