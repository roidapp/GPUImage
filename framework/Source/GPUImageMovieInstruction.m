//
//  GPUImageMovieInstruction.m
//  GPUImage
//
//  Created by Eric Yang on 6/12/14.
//  Copyright (c) 2014 Brad Larson. All rights reserved.
//

#import "GPUImageMovieInstruction.h"

@implementation GPUImageMovieInstruction

@synthesize timeRange               = _timeRange;
@synthesize enablePostProcessing    = _enablePostProcessing;
@synthesize containsTweening        = _containsTweening;
@synthesize requiredSourceTrackIDs  = _requiredSourceTrackIDs;
@synthesize passthroughTrackID      = _passthroughTrackID;

- (id)initTransitionWithSourceTrackIDs:(NSArray *)sourceTrackIDs forTimeRange:(CMTimeRange)timeRange
{
	self = [super init];
	if (self) {
		_requiredSourceTrackIDs = sourceTrackIDs;
		_passthroughTrackID = kCMPersistentTrackID_Invalid;
		_timeRange = timeRange;
		_containsTweening = TRUE;
		_enablePostProcessing = FALSE;
	}
	
	return self;
}

@end
