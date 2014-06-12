//
//  GPUImageMovieFrameInput.m
//  GPUImage
//
//  Created by Eric Yang on 6/12/14.
//  Copyright (c) 2014 Brad Larson. All rights reserved.
//

#import "GPUImageMovieFrameInput.h"
#import "GPUImageContext.h"

@implementation GPUImageMovieFrameInput
- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
{
    if (!isRecording)
    {
        [firstInputFramebuffer unlock];
        return;
    }
    
    // Drop frames forced by images and other things with no time constants
    // Also, if two consecutive times with the same value are added to the movie, it aborts recording, so I bail on that case
    if ( (CMTIME_IS_INVALID(frameTime)) || (CMTIME_COMPARE_INLINE(frameTime, ==, previousFrameTime)) || (CMTIME_IS_INDEFINITE(frameTime)) )
    {
        [firstInputFramebuffer unlock];
        return;
    }
    
    if (CMTIME_IS_INVALID(startTime))
    {
        runSynchronouslyOnContextQueue(_movieWriterContext, ^{
            if ((videoInputReadyCallback == NULL) && (assetWriter.status != AVAssetWriterStatusWriting))
            {
                [assetWriter startWriting];
            }
            
            [assetWriter startSessionAtSourceTime:frameTime];
            startTime = frameTime;
        });
    }
    
    GPUImageFramebuffer *inputFramebufferForBlock = firstInputFramebuffer;
    glFinish();
    
    runAsynchronouslyOnContextQueue(_movieWriterContext, ^{
        if (!assetWriterVideoInput.readyForMoreMediaData && _encodingLiveVideo)
        {
            [inputFramebufferForBlock unlock];
            NSLog(@"1: Had to drop a video frame: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, frameTime)));
            return;
        }
        
        // Render the frame with swizzled colors, so that they can be uploaded quickly as BGRA frames
        [_movieWriterContext useAsCurrentContext];
        [self renderAtInternalSizeUsingFramebuffer:inputFramebufferForBlock];
        
        CVPixelBufferRef pixel_buffer = NULL;
        
        if ([GPUImageContext supportsFastTextureUpload])
        {
            pixel_buffer = renderTarget;
            CVPixelBufferLockBaseAddress(pixel_buffer, 0);
        }
        else
        {
            CVReturn status = CVPixelBufferPoolCreatePixelBuffer (NULL, [assetWriterPixelBufferInput pixelBufferPool], &pixel_buffer);
            if ((pixel_buffer == NULL) || (status != kCVReturnSuccess))
            {
                CVPixelBufferRelease(pixel_buffer);
                return;
            }
            else
            {
                CVPixelBufferLockBaseAddress(pixel_buffer, 0);
                
                GLubyte *pixelBufferData = (GLubyte *)CVPixelBufferGetBaseAddress(pixel_buffer);
                glReadPixels(0, 0, videoSize.width, videoSize.height, GL_RGBA, GL_UNSIGNED_BYTE, pixelBufferData);
            }
        }
        
        void(^write)() = ^() {
            while( ! assetWriterVideoInput.readyForMoreMediaData && ! _encodingLiveVideo && ! videoEncodingIsFinished ) {
                NSDate *maxDate = [NSDate dateWithTimeIntervalSinceNow:0.1];
                //            NSLog(@"video waiting...");
                [[NSRunLoop currentRunLoop] runUntilDate:maxDate];
            }
            if (!assetWriterVideoInput.readyForMoreMediaData)
            {
                NSLog(@"2: Had to drop a video frame: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, frameTime)));
            }
            else if(self.assetWriter.status == AVAssetWriterStatusWriting)
            {
                if (![assetWriterPixelBufferInput appendPixelBuffer:pixel_buffer withPresentationTime:frameTime])
                    NSLog(@"Problem appending pixel buffer at time: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, frameTime)));
            }
            else
            {
                NSLog(@"Couldn't write a frame");
                //NSLog(@"Wrote a video frame: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, frameTime)));
            }
            CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);
            
            previousFrameTime = frameTime;
            
            if (![GPUImageContext supportsFastTextureUpload])
            {
                CVPixelBufferRelease(pixel_buffer);
            }
        };
        
        write();
        
        [inputFramebufferForBlock unlock];
    });
}

@end
