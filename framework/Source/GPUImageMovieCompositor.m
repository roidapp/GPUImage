//
//  GPUImageMovieCompositor.m
//  GPUImage
//
//  Created by Eric Yang on 6/12/14.
//  Copyright (c) 2014 Brad Larson. All rights reserved.
//

#import "GPUImageMovieCompositor.h"
#import "GPUImageMovieInstruction.h"
#import "GPUImage.h"

@interface GPUImageMovieCompositor() {
    BOOL								_shouldCancelAllRequests;
    BOOL								_renderContextDidChange;
    dispatch_queue_t					_renderingQueue;
    dispatch_queue_t					_renderContextQueue;
    AVVideoCompositionRenderContext*	_renderContext;
    CVPixelBufferRef					_previousBuffer;
    CGAffineTransform                   _renderTransform;
}

@end

@implementation GPUImageMovieCompositor

- (NSDictionary*)sourcePixelBufferAttributes
{
    return @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
			  (NSString*)kCVPixelBufferOpenGLESCompatibilityKey : [NSNumber numberWithBool:YES]};
}

- (NSDictionary*)requiredPixelBufferAttributesForRenderContext
{
    return @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],
			  (NSString*)kCVPixelBufferOpenGLESCompatibilityKey : [NSNumber numberWithBool:YES]};
}


- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext
{
	dispatch_sync(_renderContextQueue, ^() {
		_renderContext = newRenderContext;
		_renderContextDidChange = YES;
	});
}

- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request
{
	@autoreleasepool {
		dispatch_async(_renderingQueue,^() {
			
			// Check if all pending requests have been cancelled
			if (_shouldCancelAllRequests) {
				[request finishCancelledRequest];
			} else {
				NSError *err = nil;
				// Get the next rendererd pixel buffer
				CVPixelBufferRef resultPixels = [self newRenderedPixelBufferForRequest:request error:&err];
				
				if (resultPixels) {
					// The resulting pixelbuffer from OpenGL renderer is passed along to the request
					[request finishWithComposedVideoFrame:resultPixels];
					CFRelease(resultPixels);
				} else {
					[request finishWithError:err];
				}
			}
		});
	}
}

- (void)cancelAllPendingVideoCompositionRequests
{
	// pending requests will call finishCancelledRequest, those already rendering will call finishWithComposedVideoFrame
	_shouldCancelAllRequests = YES;
	
	dispatch_barrier_async(_renderingQueue, ^() {
		// start accepting requests again
		_shouldCancelAllRequests = NO;
	});
}

- (CVPixelBufferRef)newRenderedPixelBufferForRequest:(AVAsynchronousVideoCompositionRequest *)request error:(NSError **)errOut
{
	CVPixelBufferRef dstPixels = nil;
	
	// tweenFactor indicates how far within that timeRange are we rendering this frame. This is normalized to vary between 0.0 and 1.0.
	// 0.0 indicates the time at first frame in that videoComposition timeRange
	// 1.0 indicates the time at last frame in that videoComposition timeRange
	//float tweenFactor = factorForTimeInRange(request.compositionTime, request.videoCompositionInstruction.timeRange);
	
	GPUImageMovieInstruction *currentInstruction = request.videoCompositionInstruction;
	NSArray *trackIDs = currentInstruction.requiredSourceTrackIDs;
    
    CVPixelBufferRef buffer0 = [request sourceFrameByTrackID:[trackIDs[0] intValue]];
    CVPixelBufferRef buffer1 = NULL;
    if (currentInstruction.requiredSourceTrackIDs.count ==2) {
        buffer1 = [request sourceFrameByTrackID:[trackIDs[1] intValue]];
    }
	
	// Destination pixel buffer into which we render the output
	dstPixels = [_renderContext newPixelBuffer];
	
	// Recompute normalized render transform everytime the render context changes
	if (_renderContextDidChange) {
		// The renderTransform returned by the renderContext is in X: [0, w] and Y: [0, h] coordinate system
		// But since in this sample we render using OpenGLES which has its coordinate system between [-1, 1] we compute a normalized transform
		CGSize renderSize = _renderContext.size;
		CGSize destinationSize = CGSizeMake(CVPixelBufferGetWidth(dstPixels), CVPixelBufferGetHeight(dstPixels));
		CGAffineTransform renderContextTransform = {renderSize.width/2, 0, 0, renderSize.height/2, renderSize.width/2, renderSize.height/2};
		CGAffineTransform destinationTransform = {2/destinationSize.width, 0, 0, 2/destinationSize.height, -1, -1};
		CGAffineTransform normalizedRenderTransform = CGAffineTransformConcat(CGAffineTransformConcat(renderContextTransform, _renderContext.renderTransform), destinationTransform);

        _renderTransform = normalizedRenderTransform;
		
		_renderContextDidChange = NO;
	}
	
    if (trackIDs.count == 1) {
        [self renderPixelBuffer:dstPixels usingSourceBuffer:buffer0 time:request.compositionTime];
    } else if (trackIDs.count == 2) {
        [self renderPixelBuffer:dstPixels usingSourceBuffer0:buffer0 andSourceBuffer1:buffer1 time:request.compositionTime];
    }
    
	return dstPixels;
}

- (void)renderPixelBuffer:(CVPixelBufferRef)destinationPixelBuffer
       usingSourceBuffer0:(CVPixelBufferRef)foregroundPixelBuffer
         andSourceBuffer1:(CVPixelBufferRef)backgroundPixelBuffer
                     time:(CMTime)time
{
    
}

- (void)renderPixelBuffer:(CVPixelBufferRef)destinationPixelBuffer
       usingSourceBuffer:(CVPixelBufferRef)foregroundPixelBuffer
                     time:(CMTime)time
{
    
}

@end
