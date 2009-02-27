//
//  metajobs.h
//  gstuffer
//
//  Created by Charles Parnot on 7/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GSMetajobs : NSObject
{
	NSMutableSet *metajobs;
	//NSTimeInterval pollingInterval;
	//NSString *metajobsDirectory;
	BOOL running;
}

//@property (readwrite) NSTimeInterval pollingInterval;
//@property (readwrite, copy) NSString *metajobsDirectory;
@property (readwrite) BOOL running;

- (void)start;
- (void)stop;

@end

@interface GSMetajobs (GSMetajobDelegate)

// GEZMetaJob delegate methods
- (void)metaJobDidStart:(GEZMetaJob *)metaJob;
- (void)metaJobDidSuspend:(GEZMetaJob *)metaJob;
- (void)metaJob:(GEZMetaJob *)metaJob didSubmitTaskAtIndex:(int)index;
- (void)metaJob:(GEZMetaJob *)metaJob didProcessTaskAtIndex:(int)index;

@end
