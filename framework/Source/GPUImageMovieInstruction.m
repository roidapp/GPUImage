//
//  GPUImageMovieInstruction.m
//  GPUImage
//
//  Created by Eric Yang on 6/12/14.
//  Copyright (c) 2014 Brad Larson. All rights reserved.
//

#import "GPUImageMovieInstruction.h"

@interface GPUImageMovieInstruction()
@property(nonatomic, strong)NSDictionary *outputMap;
@end

@implementation GPUImageMovieInstruction

@synthesize timeRange               = _timeRange;
@synthesize enablePostProcessing    = _enablePostProcessing;
@synthesize containsTweening        = _containsTweening;
@synthesize requiredSourceTrackIDs  = _requiredSourceTrackIDs;
@synthesize passthroughTrackID      = _passthroughTrackID;

- (id)initTransitionWithSourceTrackIDs:(NSArray *)sourceTrackIDs indexes:(NSDictionary *)outputMap forTimeRange:(CMTimeRange)timeRange
{
	self = [super init];
	if (self) {
		_requiredSourceTrackIDs = sourceTrackIDs;
		_passthroughTrackID = kCMPersistentTrackID_Invalid;
		_timeRange = timeRange;
		_containsTweening = TRUE;
		_enablePostProcessing = TRUE;
        _outputMap = outputMap;
	}
	
	return self;
}

- (NSInteger)indexOfTrackID:(NSNumber *)trackID
{
    return [_outputMap[trackID] intValue];
}
@end
