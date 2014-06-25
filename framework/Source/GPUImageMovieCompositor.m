//
//  GPUImageMovieCompositor.m
//  GPUImage
//
//  Created by Eric Yang on 6/12/14.
//  Copyright (c) 2014 Brad Larson. All rights reserved.
//

#import "GPUImageMovieCompositor.h"
#import "GPUImageMovieInstruction.h"
#import "GPUImageMovieFrameOutput.h"
#import "GPUImageMovieFrameInput.h"

#define SuppressPerformSelectorLeakWarning(Stuff) do { \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
Stuff; \
_Pragma("clang diagnostic pop") \
} while (0)

static id videoStyle = nil;

@interface GPUImageMovieCompositor() {
    BOOL								_shouldCancelAllRequests;
    BOOL								_renderContextDidChange;
    dispatch_queue_t					_renderContextQueue;
    AVVideoCompositionRenderContext*	_renderContext;
    CVPixelBufferRef					_previousBuffer;
    CGAffineTransform                   _renderTransform;
}

@end

@implementation GPUImageMovieCompositor
+ (void)setCurrStyle:(VideoStyle *)style
{
    videoStyle = style;
}

- (instancetype)init{
    self = [super init];
    if (self){
		_renderContextQueue = dispatch_queue_create("com.apple.aplcustomvideocompositor.rendercontextqueue", DISPATCH_QUEUE_SERIAL);
        SuppressPerformSelectorLeakWarning([videoStyle performSelector:NSSelectorFromString(@"setCompositor:") withObject:self];);
    }
    return self;
}

- (void)dealloc{
    dispatch_release(_renderContextQueue);
}

- (NSDictionary*)sourcePixelBufferAttributes
{
    return @{(NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
             (NSString*)kCVPixelBufferOpenGLESCompatibilityKey : [NSNumber numberWithBool:YES]};
}

- (NSDictionary*)requiredPixelBufferAttributesForRenderContext
{
    return @{(NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],
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
        runAsynchronouslyOnVideoProcessingQueue(^{
            // Check if all pending requests have been cancelled
			if (_shouldCancelAllRequests) {
				[request finishCancelledRequest];
			} else {
				NSError *err = nil;
                [_delegate compositorWillProcessFrameAtTime:request.compositionTime];
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
	
	dispatch_barrier_async([GPUImageContext sharedContextQueue], ^() {
		// start accepting requests again
		_shouldCancelAllRequests = NO;
	});
}

- (CVPixelBufferRef)newRenderedPixelBufferForRequest:(AVAsynchronousVideoCompositionRequest *)request error:(NSError **)errOut
{
	CVPixelBufferRef dstPixels = nil;
	
	GPUImageMovieInstruction *currentInstruction = request.videoCompositionInstruction;
	NSArray *trackIDs = currentInstruction.requiredSourceTrackIDs;
    
    CVPixelBufferRef buffer[8] = {NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
    NSAssert(trackIDs.count <= 8, @"tracks out of range");
    for (int i = 0; i < trackIDs.count; i++) {
        CMPersistentTrackID trackID = [trackIDs[i] intValue];
        buffer[i] = [request sourceFrameByTrackID:trackID];
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
	
    CMTime currTime = request.compositionTime;
    [_result setPixelBuffer:dstPixels];
    
    NSArray *outputArray = _outputs;
    for (int i = 0; i < trackIDs.count && i < [outputArray count]; i++) {
        NSInteger idx = [currentInstruction indexOfTrackID:trackIDs[i]];
        GPUImageMovieFrameOutput *output = outputArray[idx];
        [output processPixelBuffer:buffer[i] withSampleTime:currTime];
    }
    
	return dstPixels;
}

@end
