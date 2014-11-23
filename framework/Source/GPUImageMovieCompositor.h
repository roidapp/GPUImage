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

#define kGPUImageMovieCompositorCreatedNotification @"GPUImageMovieCompositorCreatedNotification"

@class GPUImageOutput;
@class GPUImageMovieFrameOutput;
@class GPUImageMovieFrameInput;
@class VideoStyle;

@protocol GPUImageMovieCompositorDelegate <NSObject>
- (void)compositorWillProcessFrameAtTime:(CMTime)time;
@end

@interface GPUImageMovieCompositor : NSObject<AVVideoCompositing>

@property (nonatomic, assign) BOOL          valid;
@property (nonatomic, strong) NSArray       *outputs;
@property (nonatomic, strong) GPUImageMovieFrameInput    *result;
@property (nonatomic, assign) id<GPUImageMovieCompositorDelegate> delegate;

+ (void)setCurrStyle:(VideoStyle*)style;

@end
