//
//  GPUImageMovieCompositor.h
//  GPUImage
//
//  Created by Eric Yang on 6/12/14.
//  Copyright (c) 2014 Brad Larson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "GPUImage.h"

@class GPUImageOutput;
@class GPUImageMovieFrameOutput;
@interface GPUImageMovieCompositor : NSObject<AVVideoCompositing>
@property(nonatomic, strong)GPUImageMovieFrameOutput   *output0;
@property(nonatomic, strong)GPUImageMovieFrameOutput   *output1;
@property(nonatomic, strong)id<GPUImageInput>           reuslt;
@end
